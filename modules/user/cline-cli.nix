{ pkgs, ... }:

let
  cline = pkgs.buildNpmPackage rec {
    pname = "cline";
    version = "1.0.1"; # bump when upstream updates

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
      # put a dummy first; run once to get the real one
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };

    # NPM dependency lock for sandboxed builds
    npmDepsHash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";

    dontNpmBuild = true; # no build step needed for this CLI

    meta.mainProgram = "cline";
  };
in {
  home.packages = [ cline ];
}