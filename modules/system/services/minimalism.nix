{ scheme, host, port, lanPort, streamPort, expose, edgePort }:

{ config, lib, pkgs, ... }:
let
  siteName   = "minimalism-site";
  etcPrefix  = "minimalism";         # stuff lands in /etc/minimalism
  stateDir   = "/var/lib/${siteName}";
  py         = pkgs.python3;         # just for `python -m http.server`
in
{
  #### Install your site files into /etc
  #
  # Adjust ./custom/minimalism/... to wherever you put these files
  # inside your flake/repo.

  environment.etc."${etcPrefix}/index.html".source               = ./custom/minimalism/index.html;
  environment.etc."${etcPrefix}/about.html".source               = ./custom/minimalism/about.html;
  environment.etc."${etcPrefix}/gallery.html".source             = ./custom/minimalism/gallery.html;
  environment.etc."${etcPrefix}/bibliography.html".source        = ./custom/minimalism/bibliography.html;
  environment.etc."${etcPrefix}/what-is-minimalism.html".source  = ./custom/minimalism/what-is-minimalism.html;
  environment.etc."${etcPrefix}/key-artists.html".source         = ./custom/minimalism/key-artists.html;

  # Shared layout / assets
  environment.etc."${etcPrefix}/header.html".source              = ./custom/minimalism/header.html;
  environment.etc."${etcPrefix}/include.js".source               = ./custom/minimalism/include.js;
  environment.etc."${etcPrefix}/style.css".source                = ./custom/minimalism/style.css;

  # Images
  environment.etc."${etcPrefix}/AWallforApricots.png".source              = ./custom/minimalism/AWallforApricots.png;
  environment.etc."${etcPrefix}/BlueGreenYellowOrangeRed.jpg".source      = ./custom/minimalism/BlueGreenYellowOrangeRed.jpg;
  environment.etc."${etcPrefix}/HyenaStomp.jpg".source                    = ./custom/minimalism/HyenaStomp.jpg;
  environment.etc."${etcPrefix}/NineSidedFigure.jpg".source               = ./custom/minimalism/NineSidedFigure.jpg;
  environment.etc."${etcPrefix}/StoneSouth3.jpg".source                   = ./custom/minimalism/StoneSouth3.jpg;
  environment.etc."${etcPrefix}/TableObject.jpg".source                   = ./custom/minimalism/TableObject.jpg;
  environment.etc."${etcPrefix}/TomlinsonCourtPark.jpg".source            = ./custom/minimalism/TomlinsonCourtPark.jpg;
  environment.etc."${etcPrefix}/Untitled.jpg".source                      = ./custom/minimalism/Untitled.jpg;
  environment.etc."${etcPrefix}/UntitledFrank.jpg".source                 = ./custom/minimalism/UntitledFrank.jpg;
  environment.etc."${etcPrefix}/WhosAfraidOfRedYellowAndBlueII.jpg".source = ./custom/minimalism/WhosAfraidOfRedYellowAndBlueII.jpg;

  #### Service: copy to /var/lib and serve over localhost:${port}
  systemd.services.${siteName} = {
    description = "Minimalism static website for ${host}";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      StateDirectory  = siteName;
      WorkingDirectory = stateDir;

      # Copy everything from /etc/minimalism into /var/lib/minimalism-site
      ExecStartPre = [
        # Make sure dir exists
        "${pkgs.coreutils}/bin/install -d ${stateDir}"

        # Copy HTML
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/index.html ${stateDir}/index.html"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/about.html ${stateDir}/about.html"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/gallery.html ${stateDir}/gallery.html"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/bibliography.html ${stateDir}/bibliography.html"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/what-is-minimalism.html ${stateDir}/what-is-minimalism.html"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/key-artists.html ${stateDir}/key-artists.html"

        # Shared layout / assets
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/header.html ${stateDir}/header.html"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/include.js ${stateDir}/include.js"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/style.css ${stateDir}/style.css"

        # Images
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/AWallforApricots.png ${stateDir}/AWallforApricots.png"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/BlueGreenYellowOrangeRed.jpg ${stateDir}/BlueGreenYellowOrangeRed.jpg"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/HyenaStomp.jpg ${stateDir}/HyenaStomp.jpg"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/NineSidedFigure.jpg ${stateDir}/NineSidedFigure.jpg"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/StoneSouth3.jpg ${stateDir}/StoneSouth3.jpg"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/TableObject.jpg ${stateDir}/TableObject.jpg"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/TomlinsonCourtPark.jpg ${stateDir}/TomlinsonCourtPark.jpg"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/Untitled.jpg ${stateDir}/Untitled.jpg"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/UntitledFrank.jpg ${stateDir}/UntitledFrank.jpg"
        "${pkgs.coreutils}/bin/install -m0644 /etc/${etcPrefix}/WhosAfraidOfRedYellowAndBlueII.jpg ${stateDir}/WhosAfraidOfRedYellowAndBlueII.jpg"
      ];

      # Simple static server; your reverse proxy hits 127.0.0.1:${port}
      ExecStart = ''
        ${py}/bin/python -m http.server ${toString port} \
          --bind 127.0.0.1 \
          --directory ${stateDir}
      '';

      DynamicUser      = true;
      NoNewPrivileges  = true;
      ProtectSystem    = "strict";
      ProtectHome      = true;
      PrivateTmp       = true;
      Restart          = "on-failure";
      RestartSec       = 3;
    };
  };
}