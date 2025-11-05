from flask import Flask, Response, request, send_file, jsonify, redirect
import subprocess
import os
import time
import json
import signal
import shutil
import tempfile
from threading import Lock

app = Flask(__name__)
VLC_HOST = os.getenv("VLC_HOST", "127.0.0.1")
PORT = os.getenv("VLC_PORT", "1234")
VLC_PROCESS = None
CHANNELS = {}
RESCAN_LOCK = Lock()

CHANNELS_CONF_PATH = os.environ.get("CHANNELS_CONF_PATH", "/var/lib/tv-controller/channels.conf")
WSCAN_ARGS = ["w_scan2", "-fa", "-A1", "-c", "US"]  # adjust region if needed
WSCAN_TIMEOUT_SEC = 600  # allow long scans (~3-5 min typical)
CURRENT_PLAYING = None

CONFIG_DIR = os.environ.get("TVCTL_STATE_DIR", "/var/lib/tv-controller")
TRANSCODE_JSON = os.path.join(CONFIG_DIR, "transcode.json")
PRESETS_JSON   = os.path.join(CONFIG_DIR, "transcode-presets.json")

BUILTIN_PRESETS = {
    "Pass-through": {"enabled": False},
    "1080p @ 6Mbps": {
        "enabled": True, "vcodec": "h264", "vb_kbps": 6000,
        "width": 1920, "height": 1080, "deinterlace": True,
        "acodec": "mp4a", "ab_kbps": 160,
    },
    "720p @ 2.5Mbps": {
        "enabled": True, "vcodec": "h264", "vb_kbps": 2500,
        "width": 1280, "height": 720, "deinterlace": True,
        "acodec": "mp4a", "ab_kbps": 128,
    },
    "480p @ 1Mbps": {
        "enabled": True, "vcodec": "h264", "vb_kbps": 1000,
        "width": 854, "height": 480, "deinterlace": True,
        "acodec": "mp4a", "ab_kbps": 96,
    },
    "360p @ 600kbps": {
        "enabled": True, "vcodec": "h264", "vb_kbps": 600,
        "width": 640, "height": 360, "deinterlace": True,
        "acodec": "mp4a", "ab_kbps": 80,
    },
}

# In-memory config (loaded at start, saved on change)
TRANSCODE = {
    "enabled": False,         # False = pass-through (your current behavior)
    "vcodec": "h264",         # h264 works everywhere
    "vb_kbps": 3000,          # video bitrate in kbps
    "width": 1280,            # scaled width (set 0 to keep source)
    "height": 720,            # scaled height (set 0 to keep source)
    "deinterlace": True,      # recommended for OTA
    "acodec": "mp4a",         # AAC
    "ab_kbps": 128,           # audio bitrate in kbps
}

# User presets loaded from disk, merged over BUILTIN_PRESETS
USER_PRESETS = {}

def _ensure_state_dir():
    os.makedirs(CONFIG_DIR, exist_ok=True)

def _deep_update(dst, src):
    for k, v in src.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict):
            _deep_update(dst[k], v)
        else:
            dst[k] = v
    return dst

def load_transcode():
    _ensure_state_dir()
    try:
        with open(TRANSCODE_JSON, "r") as f:
            data = json.load(f)
            if isinstance(data, dict):
                TRANSCODE.update(data)
    except FileNotFoundError:
        pass

def save_transcode():
    _ensure_state_dir()
    tmp = TRANSCODE_JSON + ".tmp"
    with open(tmp, "w") as f:
        json.dump(TRANSCODE, f)
    os.replace(tmp, TRANSCODE_JSON)

def load_presets():
    global USER_PRESETS
    _ensure_state_dir()
    try:
        with open(PRESETS_JSON, "r") as f:
            data = json.load(f)
            if isinstance(data, dict):
                USER_PRESETS = data
    except FileNotFoundError:
        USER_PRESETS = {}

def save_presets():
    _ensure_state_dir()
    tmp = PRESETS_JSON + ".tmp"
    with open(tmp, "w") as f:
        json.dump(USER_PRESETS, f)
    os.replace(tmp, PRESETS_JSON)

load_presets()
load_transcode()


def _vlc_alive():
    """Return True if VLC_PROCESS exists and is still running."""
    global VLC_PROCESS
    return VLC_PROCESS is not None and VLC_PROCESS.poll() is None


def load_channels_from_conf(file_path=CHANNELS_CONF_PATH):
    """
    Parse channels.conf lines like:
    NAME:freq:...:...:...:...:...:...:...:program
    We care about name, freq (kHz), and program.
    """
    channels = {}
    try:
        with open(file_path, "r") as f:
            for line in f:
                if line.strip() and not line.startswith("#"):
                    parts = line.strip().split(":")
                    if len(parts) >= 10:
                        name = parts[0].split(";")[0].strip()
                        try:
                            frequency = str(int(parts[1].strip()) * 1000)  # kHz -> Hz
                            program = str(int(parts[9].strip()))
                            # MINIMAL FIX: include 'name' so CURRENT_PLAYING has it
                            channels[name] = {"name": name, "frequency": frequency, "program": program}
                        except ValueError:
                            print(f"⚠️ Bad numeric field in line: {line.strip()}")
                    else:
                        print(f"⚠️ Malformed line: {line.strip()}")
    except FileNotFoundError:
        print(f"⚠️ channels.conf not found at: {file_path}")
    return channels


def stop_vlc():
    global VLC_PROCESS
    if VLC_PROCESS and VLC_PROCESS.poll() is None:
        VLC_PROCESS.terminate()
        try:
            VLC_PROCESS.wait(timeout=5)
        except subprocess.TimeoutExpired:
            VLC_PROCESS.kill()
        print("🛑 Stopped VLC")
    VLC_PROCESS = None


def build_vlc_sout():
    """
    Build VLC --sout chain based on TRANSCODE.
    Always ends as MPEG-TS over HTTP to VLC_HOST:PORT.
    """
    if not TRANSCODE.get("enabled", False):
        # Pass-through
        return f"#http{{mux=ts,dst={VLC_HOST}:{PORT}}}"

    vcodec   = TRANSCODE.get("vcodec", "h264")
    vb       = int(TRANSCODE.get("vb_kbps", 3000))
    width    = int(TRANSCODE.get("width", 0))
    height   = int(TRANSCODE.get("height", 0))
    deint    = 1 if TRANSCODE.get("deinterlace", True) else 0
    acodec   = TRANSCODE.get("acodec", "mp4a")
    ab       = int(TRANSCODE.get("ab_kbps", 128))

    # VLC transcode accepts width/height directly (no need for scale=)
    wh = []
    if width  > 0: wh.append(f"width={width}")
    if height > 0: wh.append(f"height={height}")
    wh_s = ("," + ",".join(wh)) if wh else ""

    # Keep it simple & broadly compatible
    trans = (
        f"#transcode{{vcodec={vcodec},vb={vb},"
        f"deinterlace={deint},"
        f"acodec={acodec},ab={ab}{wh_s}}}"
        f":http{{mux=ts,dst={VLC_HOST}:{PORT}}}"
    )
    return trans


def start_vlc(frequency, program):
    global VLC_PROCESS
    stop_vlc()
    cvlc_path = shutil.which("cvlc")
    if not cvlc_path:
        print("❌ cvlc not found!")
        return None

    sout_chain = build_vlc_sout()

    command = [
        cvlc_path,
        "--intf", "dummy",
        f"--http-host={VLC_HOST}",
        f"dvb://frequency={frequency}",
        f"--program={program}",
        f"--sout={sout_chain}",
        "--no-sout-all", "--sout-keep"
    ]
    VLC_PROCESS = subprocess.Popen(command)
    print(f"✅ Started VLC on freq={frequency}, program={program}, transcode={TRANSCODE}")
    print("VLC command:", command)

    # wait for port (your existing loop)
    for _ in range(20):
        time.sleep(0.5)
        try:
            import socket
            with socket.create_connection((VLC_HOST, int(PORT)), timeout=1):
                print("📡 VLC socket responded — ready.")
                return VLC_PROCESS
        except OSError:
            continue
    print("⚠️ VLC did not respond on port after 10s")
    return VLC_PROCESS


@app.route("/")
def serve_index():
    return send_file("index.html")


@app.route("/favicon.ico")
def favicon():
    # Served from the service WorkingDirectory (/var/lib/tv-controller)
    return send_file("favicon.ico", mimetype="image/x-icon")


@app.get("/channels")
def get_channels():
    # You asked for this to always read from file
    channels = load_channels_from_conf(CHANNELS_CONF_PATH)
    return jsonify(channels=channels)


@app.get("/start")
def start():
    channel = request.args.get("channel")
    # MINIMAL FIX: read fresh channels from disk so it matches /channels output
    chans = load_channels_from_conf(CHANNELS_CONF_PATH)
    if not channel or channel not in chans:
        return "Invalid or missing channel", 400

    info = chans[channel]
    if not start_vlc(info["frequency"], info["program"]):
        return "Failed to start VLC", 500

    # record what's playing (ensure it has 'name', 'frequency', 'program')
    global CURRENT_PLAYING, CHANNELS
    CURRENT_PLAYING = {
        "name": info.get("name", channel),
        "frequency": str(info["frequency"]),
        "program": str(info["program"]),
    }
    # keep global cache in sync (optional but harmless)
    CHANNELS = chans

    return f"Started channel '{CURRENT_PLAYING['name']}'", 200


@app.get("/stop")
def stop():
    stop_vlc()
    global CURRENT_PLAYING
    CURRENT_PLAYING = None
    return "Stopped VLC", 200


@app.get("/nowplaying")
def now_playing():
    # if VLC died unexpectedly, clear state
    global CURRENT_PLAYING
    if not _vlc_alive():
        CURRENT_PLAYING = None

    if CURRENT_PLAYING:
        # MINIMAL HARDENING: use .get to avoid KeyError
        return jsonify(
            playing=True,
            channel=CURRENT_PLAYING.get("name"),
            frequency=CURRENT_PLAYING.get("frequency"),
            program=CURRENT_PLAYING.get("program"),
        )
    else:
        return jsonify(playing=False), 200


@app.post("/rescan")
def rescan():
    """
    Robust rescan (blocking):
      - Use a lock to prevent concurrent scans (409 if busy)
      - Run w_scan with a timeout
      - Write to a temp file first; only replace channels.conf on success
      - Reload channels and return JSON with counts
    """
    if not RESCAN_LOCK.acquire(blocking=False):
        return jsonify(error="Scan already in progress"), 409

    try:
        with tempfile.NamedTemporaryFile("w+", delete=False) as tmp:
            tmp_path = tmp.name

        print("🔎 Running w_scan…")
        try:
            # Run w_scan and capture stdout directly into temp file
            with open(tmp_path, "w") as out:
                proc = subprocess.run(
                    WSCAN_ARGS, stdout=out, stderr=subprocess.PIPE, text=True,
                    timeout=WSCAN_TIMEOUT_SEC
                )
        except subprocess.TimeoutExpired:
            os.unlink(tmp_path)
            return jsonify(error=f"w_scan timed out after {WSCAN_TIMEOUT_SEC}s"), 504

        if proc.returncode != 0:
            stderr = (proc.stderr or "").strip()
            os.unlink(tmp_path)
            return jsonify(error=f"w_scan failed (code {proc.returncode})", detail=stderr), 500

        # Basic sanity check: ensure temp file has at least one non-comment channel line
        new_channels = load_channels_from_conf(tmp_path)
        if not new_channels:
            os.unlink(tmp_path)
            return jsonify(error="No channels found. Check antenna/cable/tuner."), 422

        # Move into place atomically
        shutil.move(tmp_path, CHANNELS_CONF_PATH)

        # Reload global CHANNELS
        global CHANNELS
        CHANNELS = new_channels
        print(f"✅ Rescan complete: {len(CHANNELS)} channels")
        return jsonify(ok=True, channels_found=len(CHANNELS)), 200

    except Exception as e:
        # Cleanup temp on unexpected errors
        try:
            if 'tmp_path' in locals() and os.path.exists(tmp_path):
                os.unlink(tmp_path)
        except Exception:
            pass
        return jsonify(error="Unexpected error during rescan", detail=str(e)), 500
    finally:
        RESCAN_LOCK.release()

@app.get("/playlist.m3u")
def playlist_m3u():
    chans = load_channels_from_conf(CHANNELS_CONF_PATH)
    base = request.url_root.rstrip("/")
    lines = ["#EXTM3U"]
    for name in sorted(chans.keys()):
        lines.append(f"#EXTINF:-1,{name}")
        lines.append(f"{base}/tune/{name}.ts")
    body = "\n".join(lines) + "\n"
    resp = Response(body, mimetype="audio/x-mpegurl")
    resp.headers["Content-Disposition"] = 'attachment; filename="tv.m3u"'
    return resp

@app.get("/tune/<channel>.ts")
def tune_channel(channel):
    global CURRENT_PLAYING
    chans = load_channels_from_conf(CHANNELS_CONF_PATH)
    if channel not in chans:
        return "Unknown channel", 404
    info = chans[channel]
    if not start_vlc(info["frequency"], info["program"]):
        return "Failed to start VLC", 500

    # record new now-playing info right here
    CURRENT_PLAYING = {
        "name": info["name"],
        "frequency": str(info["frequency"]),
        "program": str(info["program"]),
    }

    print(f"▶️ Now playing via /tune: {info['name']}")
    return redirect("/stream/", code=302)

@app.get("/transcode")
def get_transcode():
    return jsonify(TRANSCODE)

@app.post("/transcode")
def set_transcode():
    data = request.get_json(force=True, silent=True) or {}
    # minimal validation & coercion
    def getb(k, default):
        v = data.get(k, default)
        if isinstance(v, bool): return v
        if isinstance(v, str):  return v.lower() in ("1","true","yes","on")
        return bool(v)

    def geti(k, default, lo=None, hi=None):
        try:
            v = int(data.get(k, default))
        except Exception:
            v = default
        if lo is not None: v = max(lo, v)
        if hi is not None: v = min(hi, v)
        return v

    def gets(k, default):
        v = data.get(k, default)
        if v is None: return default
        return str(v)

    TRANSCODE["enabled"]    = getb("enabled", TRANSCODE["enabled"])
    TRANSCODE["vcodec"]     = gets("vcodec", TRANSCODE["vcodec"])
    TRANSCODE["vb_kbps"]    = geti("vb_kbps", TRANSCODE["vb_kbps"], 100, 20000)
    TRANSCODE["width"]      = geti("width", TRANSCODE["width"], 0, 4096)
    TRANSCODE["height"]     = geti("height", TRANSCODE["height"], 0, 2160)
    TRANSCODE["deinterlace"]= getb("deinterlace", TRANSCODE["deinterlace"])
    TRANSCODE["acodec"]     = gets("acodec", TRANSCODE["acodec"])
    TRANSCODE["ab_kbps"]    = geti("ab_kbps", TRANSCODE["ab_kbps"], 32, 512)

    save_transcode()
    # NOTE: We do NOT auto-restart the stream (avoids kicking viewers).
    # New settings apply on next tune, or after /stop then play again.
    return jsonify(ok=True, transcode=TRANSCODE)

@app.get("/presets")
def get_presets():
    # Merge names; user presets override built-ins if same name
    names = list({**BUILTIN_PRESETS, **USER_PRESETS}.keys())
    return jsonify({
        "presets": names,
        "builtin": list(BUILTIN_PRESETS.keys()),
        "user": list(USER_PRESETS.keys()),
        "current": TRANSCODE,
    })

@app.post("/presets/apply")
def apply_preset():
    data = request.get_json(force=True, silent=True) or {}
    name = (data.get("name") or "").strip()
    if not name:
        return jsonify(error="Missing preset name"), 400

    # Resolve preset (user overrides built-in)
    base = {}
    if name in BUILTIN_PRESETS:
        base = json.loads(json.dumps(BUILTIN_PRESETS[name]))
    if name in USER_PRESETS:
        base = json.loads(json.dumps(USER_PRESETS[name]))

    if not base:
        return jsonify(error=f"Preset not found: {name}"), 404

    # Apply preset to active config (replace, not merge with previous)
    TRANSCODE.clear()
    TRANSCODE.update(base)
    save_transcode()
    return jsonify(ok=True, applied=name, transcode=TRANSCODE)

@app.post("/presets/save")
def save_preset():
    data = request.get_json(force=True, silent=True) or {}
    name = (data.get("name") or "").strip()
    cfg  = data.get("config")
    if not name:
        return jsonify(error="Missing preset name"), 400
    if not isinstance(cfg, dict):
        return jsonify(error="Missing/invalid config"), 400

    # sanitize a few fields
    def geti(k, d): 
        try: return int(cfg.get(k, d))
        except: return d
    def getb(k, d):
        v = cfg.get(k, d)
        if isinstance(v, bool): return v
        if isinstance(v, str):  return v.lower() in ("1","true","yes","on")
        return bool(v)
    def gets(k, d): 
        v = cfg.get(k, d); 
        return d if v is None else str(v)

    cleaned = {
        "enabled":    getb("enabled", False),
        "vcodec":     gets("vcodec", "h264"),
        "vb_kbps":    max(100, min(20000, geti("vb_kbps", 3000))),
        "width":      max(0,   min(4096,  geti("width", 1280))),
        "height":     max(0,   min(2160,  geti("height", 720))),
        "deinterlace":getb("deinterlace", True),
        "acodec":     gets("acodec", "mp4a"),
        "ab_kbps":    max(32,  min(512,   geti("ab_kbps", 128))),
    }

    USER_PRESETS[name] = cleaned
    save_presets()
    return jsonify(ok=True, saved=name, preset=cleaned)

@app.get("/presets/<name>")
def get_preset_by_name(name):
    name = name.strip()
    if name in USER_PRESETS:
        return jsonify(USER_PRESETS[name])
    if name in BUILTIN_PRESETS:
        return jsonify(BUILTIN_PRESETS[name])
    return jsonify(error="Not found"), 404