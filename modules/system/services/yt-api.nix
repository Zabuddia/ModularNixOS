{ scheme, host, port, lanPort }:
{ config, pkgs, lib, ... }:

let
  # Python env with FastAPI + Uvicorn
  py = pkgs.python3.withPackages (ps: with ps; [ fastapi uvicorn ]);

  # Your app code, kept verbatim
  ytApiPy = pkgs.writeText "yt_api.py" ''
    #!/usr/bin/env python3
    # Download-then-serve (no piping). Files are deleted right after response.
    # Requires: yt-dlp, ffmpeg

    from fastapi import FastAPI, HTTPException, BackgroundTasks
    from fastapi.responses import FileResponse, PlainTextResponse
    import tempfile, subprocess, os, shutil, mimetypes
    from typing import Optional, List

    app = FastAPI()

    COMMON_FLAGS = [
        "-q", "--no-playlist",
        "--no-write-subs", "--no-write-thumbnail", "--no-write-info-json",
    ]

    def _run_yt_dlp_to_temp(
        url: str,
        fmt: str,
        merge: Optional[str] = None,
        extra: Optional[List[str]] = None,
    ):
        tmpdir = tempfile.mkdtemp(prefix="ytapi-")
        outtmpl = "%(id)s.%(ext)s"
        cmd = ["yt-dlp", *COMMON_FLAGS, "-f", fmt]
        if merge: cmd += ["--merge-output-format", merge]
        if extra: cmd += extra
        cmd += ["-P", tmpdir, "-o", outtmpl, url]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode != 0:
            shutil.rmtree(tmpdir, ignore_errors=True)
            err = (proc.stderr or b"").decode("utf-8", "ignore").strip()
            raise HTTPException(status_code=502, detail=f"yt-dlp failed ({proc.returncode}): {err or 'unknown error'}")
        files = [os.path.join(tmpdir, f) for f in os.listdir(tmpdir) if os.path.isfile(os.path.join(tmpdir, f))]
        if not files:
            shutil.rmtree(tmpdir, ignore_errors=True)
            raise HTTPException(500, "Download finished but no output file was found.")
        files.sort(key=lambda p: os.path.getsize(p), reverse=True)
        return tmpdir, files[0]

    def _cleanup_dir(path: str):
        shutil.rmtree(path, ignore_errors=True)

    @app.get("/", response_class=PlainTextResponse)
    def root():
        return (
            "Endpoints:\\n"
            "  /audio?u=<url>          (MP3)\\n"
            "  /audio-whisper?u=<url>  (WAV 16 kHz mono, best for Whisper)\\n"
            "  /video?u=<url>          (<=360p + bestaudio -> MP4)\\n"
        )

    @app.get("/audio")
    def audio(u: str, background: BackgroundTasks):
        tmpdir, fpath = _run_yt_dlp_to_temp(
            u, fmt="bestaudio/best",
            extra=["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        )
        background.add_task(_cleanup_dir, tmpdir)
        return FileResponse(fpath, media_type="audio/mpeg", filename=os.path.basename(fpath), background=background)

    @app.get("/audio-whisper")
    def audio_whisper(u: str, background: BackgroundTasks):
        tmpdir = tempfile.mkdtemp(prefix="ytapi-")
        def _run(cmd):
            p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if p.returncode != 0:
                shutil.rmtree(tmpdir, ignore_errors=True)
                raise HTTPException(502, (p.stderr or b"").decode("utf-8", "ignore").strip() or "ffmpeg/yt-dlp failed")
        in_tmpl = "%(id)s.%(ext)s"
        _run(["yt-dlp", *COMMON_FLAGS, "-f", "bestaudio/best", "-P", tmpdir, "-o", in_tmpl, u])
        files = sorted(
            [os.path.join(tmpdir, f) for f in os.listdir(tmpdir) if os.path.isfile(os.path.join(tmpdir, f))],
            key=os.path.getsize, reverse=True
        )
        if not files:
            shutil.rmtree(tmpdir, ignore_errors=True)
            raise HTTPException(500, "No audio file produced by yt-dlp")
        in_path = files[0]
        out_path = os.path.join(tmpdir, "audio-16k-mono.wav")
        _run([
            "ffmpeg", "-y", "-v", "error",
            "-i", in_path, "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le",
            "-map_metadata", "-1", out_path
        ])
        try: os.remove(in_path)
        except: pass
        background.add_task(_cleanup_dir, tmpdir)
        return FileResponse(out_path, media_type="audio/wav", filename=os.path.basename(out_path), background=background)

    @app.get("/video")
    def video(u: str, background: BackgroundTasks):
        tmpdir, fpath = _run_yt_dlp_to_temp(
            u,
            fmt="bestvideo[height<=360]+bestaudio/best",
            extra=["--recode-video", "mp4", "--ppa", "VideoConvertor:-movflags +faststart"]
        )
        background.add_task(_cleanup_dir, tmpdir)
        return FileResponse(fpath, media_type="video/mp4", filename=os.path.basename(fpath), background=background)

    @app.get("/favicon.ico")
    def favicon():
        return PlainTextResponse("", status_code=204)
  '';

  # Put yt_api.py into a directory so uvicorn can import "yt_api:app"
  appDir = pkgs.runCommand "yt-api-src" {} ''
    mkdir -p "$out"
    cp ${ytApiPy} "$out/yt_api.py"
  '';

  start = pkgs.writeShellScript "start-yt-api" ''
    exec ${py}/bin/uvicorn yt_api:app \
      --host 127.0.0.1 \
      --port ${toString port} \
      --app-dir ${appDir}
  '';
in
{
  systemd.services.yt-api = {
    description = "YouTube download/convert API (FastAPI + yt-dlp + ffmpeg)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # ffmpeg + yt-dlp binaries on PATH for the service
    path = [ pkgs.ffmpeg pkgs.yt-dlp ];

    serviceConfig = {
      ExecStart = start;
      DynamicUser = true;
      WorkingDirectory = "/";
      Restart = "on-failure";
      RestartSec = 3;
      # Small hardening (still simple)
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      AmbientCapabilities = "";
    };
  };
}