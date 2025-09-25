from flask import Flask, Response, request, send_file, jsonify
import subprocess
import os
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

CHANNELS_CONF_PATH = os.environ.get("CHANNELS_CONF_PATH", "/var/lib/tv-controller/channnels.conf")
WSCAN_ARGS = ["w_scan2", "-fa", "-A1", "-c", "US"]  # adjust region if needed
WSCAN_TIMEOUT_SEC = 600  # allow long scans (~3-5 min typical)
CURRENT_PLAYING = None


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


def start_vlc(frequency, program):
    """
    Start VLC HTTP mux to :PORT for given frequency + program.
    """
    global VLC_PROCESS
    stop_vlc()
    cvlc_path = shutil.which("cvlc")
    if not cvlc_path:
        print("❌ cvlc not found!")
        return None

    command = [
        cvlc_path,
        "--intf", "dummy",
        f"dvb://frequency={frequency}",
        f"--program={program}",
        f"--sout=#http{{mux=ts,dst={VLC_HOST}:{PORT}}}",
        "--no-sout-all", "--sout-keep"
    ]
    VLC_PROCESS = subprocess.Popen(command)
    print(f"✅ Started VLC on freq={frequency}, program={program}")
    print("VLC command:", command)
    return VLC_PROCESS


@app.route("/")
def serve_index():
    return send_file("index.html")


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
    # Construct absolute HTTP stream URL
    # request.url_root includes scheme+host+port and ends with '/'
    stream_url = request.url_root.rstrip("/") + "/stream"
    body = f"#EXTM3U\n#EXTINF:-1,TV Controller Stream\n{stream_url}\n"

    # audio/x-mpegurl and application/vnd.apple.mpegurl are both OK; VLC recognizes either
    resp = Response(body, mimetype="audio/x-mpegurl")
    resp.headers["Content-Disposition"] = 'attachment; filename="tv-stream.m3u"'
    return resp