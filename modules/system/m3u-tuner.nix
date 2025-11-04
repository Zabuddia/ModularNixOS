{ config, pkgs, lib, ... }:

let
  dataDir = "/var/lib/m3u-tuner";
  port = 8081;

  script = pkgs.writeText "m3u-tuner.py" ''
    #!/usr/bin/env python3
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import subprocess

    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/playlist.m3u":
                self.send_response(200)
                self.send_header("Content-Type", "application/x-mpegURL")
                self.end_headers()
                self.wfile.write(b"#EXTM3U\n#EXTINF:-1,Test Channel\nhttp://127.0.0.1:${toString port}/stream/test\n")
            elif self.path == "/stream/test":
                self.send_response(200)
                self.send_header("Content-Type", "video/MP2T")
                self.end_headers()
                # ffmpeg test source (color bars)
                cmd = [
                    "${pkgs.ffmpeg}/bin/ffmpeg",
                    "-f", "lavfi",
                    "-i", "testsrc=size=640x360:rate=30",
                    "-f", "mpegts",
                    "-"
                ]
                with subprocess.Popen(cmd, stdout=subprocess.PIPE) as p:
                    while True:
                        buf = p.stdout.read(8192)
                        if not buf:
                            break
                        self.wfile.write(buf)
            else:
                self.send_error(404)

    HTTPServer(("0.0.0.0", ${toString port}), H).serve_forever()
  '';
in {
  environment.systemPackages = [ pkgs.python3 pkgs.ffmpeg ];

  systemd.services.m3u-tuner = {
    description = "Simple fake M3U tuner for Jellyfin testing";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${script}";
      Restart = "on-failure";
      WorkingDirectory = dataDir;
    };
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0755 root root -" ];
}