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
    "--extractor-args", "youtube:player_client=web_safari",
]

AUDIO_FMT = 'ba[protocol^=m3u8]/ba/bestaudio/best'
VIDEO_FMT = 'bv*[height<=360][protocol^=m3u8]+ba[protocol^=m3u8]/b[height<=360][protocol^=m3u8]/best[height<=360]'

def _run_yt_dlp_to_temp(
    url: str,
    fmt: str,
    merge: Optional[str] = None,
    extra: Optional[List[str]] = None,
):
    """
    Downloads with yt-dlp into a unique temp dir and returns (tempdir, filepath).
    Uses a fixed template '%(id)s.%(ext)s' and suppresses sidecars.
    """
    tmpdir = tempfile.mkdtemp(prefix="ytapi-")
    outtmpl = "%(id)s.%(ext)s"

    cmd = ["yt-dlp", *COMMON_FLAGS, "-f", fmt]
    if merge:
        cmd += ["--merge-output-format", merge]
    if extra:
        cmd += extra
    cmd += ["-P", tmpdir, "-o", outtmpl, url]

    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        shutil.rmtree(tmpdir, ignore_errors=True)
        err = (proc.stderr or b"").decode("utf-8", "ignore").strip()
        raise HTTPException(status_code=502, detail=f"yt-dlp failed ({proc.returncode}): {err or 'unknown error'}")

    # Find the one media file produced
    files = [os.path.join(tmpdir, f) for f in os.listdir(tmpdir) if os.path.isfile(os.path.join(tmpdir, f))]
    if not files:
        shutil.rmtree(tmpdir, ignore_errors=True)
        raise HTTPException(500, "Download finished but no output file was found.")

    # If more than one file exists, pick the largest (should be the media)
    files.sort(key=lambda p: os.path.getsize(p), reverse=True)
    return tmpdir, files[0]

def _cleanup_dir(path: str):
    shutil.rmtree(path, ignore_errors=True)

@app.get("/", response_class=PlainTextResponse)
def root():
    return (
        "Endpoints:\n"
        "  /audio?u=<url>          (MP3)\n"
        "  /audio-whisper?u=<url>  (WAV 16 kHz mono, best for Whisper)\n"
        "  /video?u=<url>          (<=360p + bestaudio -> MP4)\n"
    )

@app.get("/audio")
def audio(u: str, background: BackgroundTasks):
    # Download bestaudio and convert to MP3 (VBR 0 = highest quality VBR)
    tmpdir, fpath = _run_yt_dlp_to_temp(
        u,
        fmt=AUDIO_FMT,
        extra=["-x", "--audio-format", "mp3", "--audio-quality", "0"]
    )
    ctype = "audio/mpeg"  # MP3
    background.add_task(_cleanup_dir, tmpdir)
    return FileResponse(fpath, media_type=ctype, filename=os.path.basename(fpath), background=background)

@app.get("/audio-whisper")
def audio_whisper(u: str, background: BackgroundTasks):
    # 1) make a temp dir
    tmpdir = tempfile.mkdtemp(prefix="ytapi-")

    # helper to run commands + bubble nice errors
    def _run(cmd):
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode != 0:
            shutil.rmtree(tmpdir, ignore_errors=True)
            raise HTTPException(502, (p.stderr or b"").decode("utf-8", "ignore").strip() or "ffmpeg/yt-dlp failed")

    # 2) download bestaudio (no conversion yet)
    in_tmpl = "%(id)s.%(ext)s"
    _run(["yt-dlp", *COMMON_FLAGS, "-f", AUDIO_FMT, "-P", tmpdir, "-o", in_tmpl, u])

    # pick the media file we just got
    files = sorted(
        [os.path.join(tmpdir, f) for f in os.listdir(tmpdir) if os.path.isfile(os.path.join(tmpdir, f))],
        key=os.path.getsize, reverse=True
    )
    if not files:
        shutil.rmtree(tmpdir, ignore_errors=True)
        raise HTTPException(500, "No audio file produced by yt-dlp")
    in_path = files[0]

    # 3) convert to WAV 16 kHz mono (exactly what Whisper wants)
    out_path = os.path.join(tmpdir, "audio-16k-mono.wav")
    _run([
        "ffmpeg", "-y", "-v", "error",
        "-i", in_path,
        "-ac", "1",              # mono
        "-ar", "16000",          # 16 kHz
        "-c:a", "pcm_s16le",     # 16-bit PCM
        "-map_metadata", "-1",   # strip metadata
        out_path
    ])

    # optionally delete the source to save space
    try: os.remove(in_path)
    except: pass

    background.add_task(_cleanup_dir, tmpdir)
    return FileResponse(out_path, media_type="audio/wav", filename=os.path.basename(out_path), background=background)

@app.get("/video")
def video(u: str, background: BackgroundTasks):
    # Download ≤360p video + bestaudio, then ALWAYS output MP4 (recode/remux as needed).
    # --recode-video mp4 guarantees MP4; the PPA adds faststart for better playback.
    tmpdir, fpath = _run_yt_dlp_to_temp(
        u,
        fmt=VIDEO_FMT,
        extra=["--recode-video", "mp4", "--ppa", "VideoConvertor:-movflags +faststart"]
    )
    ctype = "video/mp4"  # Guaranteed MP4
    background.add_task(_cleanup_dir, tmpdir)
    return FileResponse(fpath, media_type=ctype, filename=os.path.basename(fpath), background=background)

# optional: quiet favicon noise
@app.get("/favicon.ico")
def favicon():
    return PlainTextResponse("", status_code=204)