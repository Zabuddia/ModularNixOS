{ lib, pkgs, inputs, ... }:
{
  imports = [
    (inputs.nix-bitcoin + "/modules/presets/secure-node.nix")
  ];

  nix-bitcoin.configVersion = "0.0.85";

  nix-bitcoin.generateSecrets = true;

  services.bitcoind = {
    enable = true;
    txindex = true;
  };
}