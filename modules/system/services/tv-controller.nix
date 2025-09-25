# modules/system/services/tv-controller.nix
{ scheme, host, port }:
{ config, pkgs, lib, ... }:

let
  # Python env with Flask + gunicorn
  py = pkgs.python3.withPackages (ps: with ps; [ flask gunicorn ]);

  # Write your Python file verbatim
  tvControllerPy = pkgs.writeText "tv_controller.py" ''
    ${/* ---- paste your Python exactly as given ---- */ ""}
    from flask import Flask, request, send_file, jsonify
    import subprocess
    import os
    import signal
    import shutil
    import tempfile
    from threading import Lock

    app = Flask(__name__)
    PORT = "8082"
    VLC_PROCESS = None
    CHANNELS = {}
    RESCAN_LOCK = Lock()

    CHANNELS_CONF_PATH = "channels.conf"
    WSCAN_ARGS = ["w_scan", "-fa", "-A1", "-c", "US"]  # adjust region if needed
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
            f"--sout=#http{{mux=ts,dst=:{PORT}}}",
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
        channels = load_channels_from_conf(CHANNELS_CONF_PATH)
        return jsonify(channels=channels)

    @app.get("/start")
    def start():
        channel = request.args.get("channel")
        chans = load_channels_from_conf(CHANNELS_CONF_PATH)
        if not channel or channel not in chans:
            return "Invalid or missing channel", 400

        info = chans[channel]
        if not start_vlc(info["frequency"], info["program"]):
            return "Failed to start VLC", 500

        global CURRENT_PLAYING, CHANNELS
        CURRENT_PLAYING = {
            "name": info.get("name", channel),
            "frequency": str(info["frequency"]),
            "program": str(info["program"]),
        }
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
        global CURRENT_PLAYING
        if not _vlc_alive():
            CURRENT_PLAYING = None

        if CURRENT_PLAYING:
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

            new_channels = load_channels_from_conf(tmp_path)
            if not new_channels:
                os.unlink(tmp_path)
                return jsonify(error="No channels found. Check antenna/cable/tuner."), 422

            shutil.move(tmp_path, CHANNELS_CONF_PATH)

            global CHANNELS
            CHANNELS = new_channels
            print(f"✅ Rescan complete: {len(CHANNELS)} channels")
            return jsonify(ok=True, channels_found=len(CHANNELS)), 200

        except Exception as e:
            try:
                if 'tmp_path' in locals() and os.path.exists(tmp_path):
                    os.unlink(tmp_path)
            except Exception:
                pass
            return jsonify(error="Unexpected error during rescan", detail=str(e)), 500
        finally:
            RESCAN_LOCK.release()

    if __name__ == "__main__":
        CHANNELS = load_channels_from_conf()
        app.run(host="0.0.0.0", port=5000)
  '';

  # Your index.html verbatim
  indexHtml = pkgs.writeText "tv-controller-index.html" ''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>TV Channel Selector</title>
  <style>
    :root{
      --bg:#0f1220;
      --card:#161a2f;
      --text:#e9ecff;
      --muted:#9aa2c7;
      --accent:#6ea8fe;
      --accent-2:#8be1ff;
      --danger:#ff6b6b;
      --ok:#79e28a;
      --btn:#1b2040;
      --btn-hover:#222855;
      --active:#2a356e;
      --shadow: 0 10px 30px rgba(0,0,0,.35);
      --radius: 14px;
    }
    * { box-sizing: border-box; }
    html, body { height: 100%; }
    body {
      margin: 0;
      font-family: system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, "Helvetica Neue", Arial, "Noto Sans", "Apple Color Emoji", "Segoe UI Emoji";
      color: var(--text);
      background: radial-gradient(1200px 800px at 10% 0%, #1b1e36 0%, #0c0f1c 55%) fixed;
      display: grid;
      grid-template-rows: auto 1fr auto;
      gap: 16px;
    }
    header, main, footer {
      width: min(1000px, 92vw);
      margin: 0 auto;
    }
    header {
      padding: 24px 0 0;
    }
    .hero {
      background: linear-gradient(160deg, var(--card), #13172a);
      border: 1px solid rgba(255,255,255,.06);
      border-radius: var(--radius);
      padding: 18px 18px;
      box-shadow: var(--shadow);
      display: grid;
      gap: 10px;
    }
    .row { display:flex; flex-wrap: wrap; gap: 10px; align-items: center; }
    .title { font-size: clamp(20px, 2.4vw, 28px); font-weight: 700; letter-spacing: .3px; }
    .muted { color: var(--muted); }
    .badge {
      display:inline-flex; align-items:center; gap:8px;
      padding: 8px 10px; border-radius: 999px;
      background: #10132a; border: 1px solid rgba(255,255,255,.06);
      font-size: 14px;
    }
    .badge a { color: var(--accent-2); text-decoration: none; }
    .badge a:hover { text-decoration: underline; }

    main { padding-bottom: 20px; }
    .panel {
      background: linear-gradient(160deg, var(--card), #13172a);
      border: 1px solid rgba(255,255,255,.06);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      padding: 18px;
      display: grid; gap: 16px;
    }
    .status-line{
      display:flex; flex-wrap:wrap; gap:10px; align-items:center; justify-content:space-between;
    }
    .status-chip{
      padding: 8px 12px; border-radius: 999px;
      background:#10132a; border:1px solid rgba(255,255,255,.06);
      font-size: 14px;
    }
    .status-chip.ok{ border-color: rgba(121,226,138,.35); }
    .status-chip.stop{ border-color: rgba(255,107,107,.35); }
    .count { color: var(--muted); font-size: 14px; }

    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
      gap: 10px;
    }
    button {
      appearance: none;
      border: 1px solid rgba(255,255,255,.08);
      background: var(--btn);
      color: var(--text);
      padding: 12px 14px;
      border-radius: 12px;
      font-size: 15px;
      cursor: pointer;
      transition: transform .04s ease, background .15s ease, border-color .15s ease;
    }
    button:hover { background: var(--btn-hover); }
    button:active { transform: translateY(1px); }
    button:disabled { opacity:.5; cursor:not-allowed; }

    .btn-row{ display:flex; flex-wrap:wrap; gap:10px; }
    .danger { background: #3a1e1e; border-color: rgba(255,107,107,.25); }
    .danger:hover { background:#4a2323; }
    .primary { background: #1a274e; border-color: rgba(110,168,254,.35); }
    .primary:hover { background:#213061; }

    .active-btn { background: var(--active); border-color: rgba(139,225,255,.35); }

    footer{
      padding: 0 0 28px;
      display:flex; align-items:center; justify-content:center;
      color: var(--muted); font-size: 13px;
    }

    /* Loading overlay */
    .overlay {
      position: fixed; inset: 0; display: none;
      align-items: center; justify-content: center; z-index: 9999;
      background: rgba(6,8,16,.72);
      backdrop-filter: blur(6px);
    }
    .overlay.show { display:flex; }
    .sheet {
      background: #0e1227; border: 1px solid rgba(255,255,255,.08);
      border-radius: 16px; padding: 20px 22px; width: min(90vw, 420px);
      display:grid; gap:10px; text-align:center;
      box-shadow: var(--shadow);
    }
    .spinner {
      width: 42px; height: 42px; border-radius: 50%;
      border: 4px solid rgba(255,255,255,.15);
      border-top-color: var(--accent);
      margin: 8px auto 2px; animation: spin 1s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg);} }
    .tiny { font-size: 12px; color: var(--muted); }

    /* Toast */
    .toast {
      position: fixed; right: 14px; bottom: 14px;
      background:#0f1430; color: var(--text);
      border:1px solid rgba(255,255,255,.08);
      border-radius: 12px; padding: 10px 12px; font-size: 14px;
      box-shadow: var(--shadow); display:none; z-index: 10000;
    }
    .toast.show { display:block; }
  </style>
</head>
<body>
  <header>
    <div class="hero">
      <div class="row">
        <div class="title">TV Channel Selector</div>
        <span class="badge">
          Watch stream at:
          <a id="stream-link" href="#" target="_blank" rel="noopener">loading…</a>
        </span>
      </div>
      <div class="muted">Pick a channel below. “Stop” halts the stream; “Rescan” searches for channels (can take a minute).</div>
    </div>
  </header>

  <main>
    <div class="panel">
      <div class="status-line">
        <div id="status" class="status-chip stop">Stream is stopped</div>
        <div class="count"><span id="channel-count">0</span> channels</div>
      </div>

      <div id="channel-buttons" class="grid" aria-live="polite"></div>

      <div class="btn-row">
        <button id="stop-btn" class="danger" onclick="stopStream()">Stop</button>
        <button id="rescan-btn" class="primary" onclick="rescanChannels()">Rescan Channels</button>
        <button id="reload-btn" onclick="loadChannels()">Reload List</button>
      </div>
    </div>
  </main>

  <footer>Made with VLC + Flask. If rescanning stalls, ensure your tuner is connected and unlocked.</footer>

  <!-- Loading Overlay -->
  <div id="overlay" class="overlay" role="dialog" aria-modal="true" aria-live="assertive">
    <div class="sheet">
      <div class="spinner" aria-hidden="true"></div>
      <div id="overlay-title" style="font-weight:600">Scanning for channels…</div>
      <div class="tiny" id="overlay-sub">This may take up to 5 minutes.</div>
    </div>
  </div>

  <!-- Toast -->
  <div id="toast" class="toast" role="status" aria-live="polite">Saved.</div>

  <script>
    let currentChannel = null;
    let channels = {};
    const els = {
      grid: () => document.getElementById("channel-buttons"),
      status: () => document.getElementById("status"),
      count: () => document.getElementById("channel-count"),
      overlay: () => document.getElementById("overlay"),
      overlayTitle: () => document.getElementById("overlay-title"),
      overlaySub: () => document.getElementById("overlay-sub"),
      toast: () => document.getElementById("toast"),
      rescanBtn: () => document.getElementById("rescan-btn"),
      stopBtn: () => document.getElementById("stop-btn"),
      reloadBtn: () => document.getElementById("reload-btn"),
    };

    function showOverlay(title = "Working…", sub = "") {
      els.overlayTitle().textContent = title;
      els.overlaySub().textContent = sub;
      els.overlay().classList.add("show");
      disableControls(true);
    }
    function hideOverlay() {
      els.overlay().classList.remove("show");
      disableControls(false);
    }
    function toast(msg, ms=3000){
      const t = els.toast();
      t.textContent = msg;
      t.classList.add("show");
      setTimeout(()=>t.classList.remove("show"), ms);
    }
    function disableControls(disabled){
      [els.rescanBtn(), els.stopBtn(), els.reloadBtn()].forEach(b=>{
        if (b) b.disabled = disabled;
      });
      document.querySelectorAll("#channel-buttons button").forEach(b=> b.disabled = disabled);
    }

    function renderButtons() {
      const container = els.grid();
      container.innerHTML = "";
      const names = Object.keys(channels).sort((a,b)=>a.localeCompare(b));
      for (const name of names) {
        const btn = document.createElement("button");
        btn.textContent = name;
        btn.onclick = () => switchChannel(name);
        if (currentChannel && currentChannel === name) btn.classList.add("active-btn");
        container.appendChild(btn);
      }
      els.count().textContent = names.length;
    }

    function updateStatus() {
      const st = els.status();
      if (currentChannel) {
        st.textContent = `Currently playing: ${currentChannel}`;
        st.classList.remove("stop"); st.classList.add("ok");
      } else {
        st.textContent = "Stream is stopped";
        st.classList.remove("ok"); st.classList.add("stop");
      }
      // update active highlight
      document.querySelectorAll("#channel-buttons button").forEach(b=>{
        if (b.textContent === currentChannel) b.classList.add("active-btn");
        else b.classList.remove("active-btn");
      });
    }

    async function loadChannels() {
      try {
        const resp = await fetch("/channels");
        const data = await resp.json();
        channels = data.channels || {};
        renderButtons();
      } catch (e) {
        console.error("Error loading channels:", e);
        toast("Failed to load channels");
      }
    }

    async function switchChannel(channel) {
      try {
        const resp = await fetch(`/start?channel=${encodeURIComponent(channel)}`);
        const txt = await resp.text();
        if (!resp.ok) throw new Error(txt || "Failed to start");
        currentChannel = channel;
        updateStatus();
        console.log(txt);
      } catch (e) {
        console.error("Error switching channel:", e);
        toast("Failed to start channel");
      }
    }

    async function stopStream() {
      try {
        const resp = await fetch("/stop");
        const txt = await resp.text();
        currentChannel = null;
        updateStatus();
        console.log(txt);
      } catch (e) {
        console.error("Error stopping VLC:", e);
        toast("Failed to stop stream");
      }
    }

    async function rescanChannels() {
      showOverlay("Scanning for channels…", "This may take 5 minutes. Please keep this tab open.");
      try {
        const resp = await fetch("/rescan", { method: "POST" });
        const data = await resp.json().catch(()=>({}));
        if (!resp.ok) {
          if (resp.status === 409) {
            hideOverlay();
            toast(data.error || "Scan already in progress");
            return;
          }
          hideOverlay();
          toast(data.error || "Rescan failed");
          return;
        }
        await loadChannels();
        hideOverlay();
        const n = data.channels_found ?? Object.keys(channels).length;
        toast(`Rescan complete — found ${n} channel${n===1?"":"s"}`);
      } catch (e) {
        console.error("Error rescanning channels:", e);
        hideOverlay();
        toast("Rescan failed");
      }
    }

    async function syncNowPlayingOnce() {
      try {
        const r = await fetch("/nowplaying");
        const s = await r.json();
        if (s.playing && s.channel) {
          currentChannel = s.channel;   // use the stored name from backend
          updateStatus();               // updates the banner + active button
        }
      } catch (e) {
        // ignore if endpoint not available
        console.debug("nowplaying failed:", e);
      }
    }

    window.onload = () => {
      const hostname = window.location.hostname;
      const link = `https://${hostname}:4436`;
      const a = document.getElementById("stream-link");
      a.href = link; a.textContent = link;
      loadChannels().then(() => {
        updateStatus();
        syncNowPlayingOnce();
    });
    };
  </script>
</body>
</html>
  '';

  # Create a runtime dir that will contain index.html and channels.conf
  # We'll copy index.html there on service start if missing.
  runtimeDir = "/var/lib/tv-controller";

  # Start script: ensure files exist, then run gunicorn
  start = pkgs.writeShellScript "start-tv-controller" ''
    set -euo pipefail
    mkdir -p ${runtimeDir}
    # copy index.html if missing
    if [ ! -f ${runtimeDir}/index.html ]; then
      cp ${indexHtml} ${runtimeDir}/index.html
    fi
    # ensure channels.conf exists
    : > ${runtimeDir}/channels.conf
    cd ${runtimeDir}
    exec ${py}/bin/gunicorn \
      --bind 127.0.0.1:${toString port} \
      --workers 1 \
      --threads 4 \
      --timeout 120 \
      --access-logfile - \
      --error-logfile - \
      tv_controller:app \
      --pythonpath ${tvControllerPy}
  '';
in
{
  systemd.services.tv-controller = {
    description = "TV Controller (Flask) + VLC tuner controller";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # Tools needed by the service
    path = [ pkgs.vlc pkgs.w_scan pkgs.coreutils ];

    serviceConfig = {
      ExecStart = start;
      WorkingDirectory = runtimeDir;

      # Create /var/lib/tv-controller owned by DynamicUser
      StateDirectory = "tv-controller";

      # Reasonable hardening
      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;

      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}