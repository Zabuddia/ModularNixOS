# modules/llama-cpp.nix
{ lib, pkgs, config, ... }:

let
  cfg = config.llama-cpp;

  # Map short model keys -> pinned GGUFs (you can add more here)
  models = {
    "qwen2.5-coder-7b" = pkgs.fetchurl {
      url = "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q5_k_m.gguf";
      sha256 = "sha256-WGhE6sTW1jIWifAZLIqo5pzYYll0pcwtklsaAzZuTRY=";
    };
    "qwen3-8b" = pkgs.fetchurl {
      url = "https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/main/Qwen3-8B-Q5_K_M.gguf";
      sha256 = "sha256-BouuFj+qlq1IAy2vTgcaaij+Z9jcyVNnYJwv8WXlJzg=";
    };
    "qwen3-14b" = pkgs.fetchurl {
      url = "https://huggingface.co/Qwen/Qwen3-14B-GGUF/resolve/main/Qwen3-14B-Q5_K_M.gguf";
      sha256 = "sha256-58mroRKcopNr6eygFBnZ+Gr0DgjKoBIw1VdLNNCOPjE=";
    };
    "qwen3-32b" = pkgs.fetchurl {
      url = "https://huggingface.co/Qwen/Qwen3-32B-GGUF/resolve/main/Qwen3-32B-Q4_K_M.gguf";
      sha256 = "sha256-79lxVhiWhm8OkQzOUnYcp3sbE4CQx/Ff4oRnbVfR9ok=";
    };
    "llama3.1-8b" = pkgs.fetchurl {
      url = "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q6_K_L.gguf";
      sha256 = "sha256-m/VZizzGxYBMUgqmNJJm0uLJoiQC4Ve9mxh9w0gG2tY=";
    };
    "nomic-embed-v2-moe" = pkgs.fetchurl {
      url = "https://huggingface.co/nomic-ai/nomic-embed-text-v2-moe-GGUF/resolve/main/nomic-embed-text-v2-moe.Q5_K_M.gguf";
      sha256 = "sha256-plRr305GKIyT155ikrvdjvp8qHwkKo5gr6nLrNxkFHE=";
    };
    "gpt-oss-20b" = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/gpt-oss-20b-GGUF/resolve/main/gpt-oss-20b-Q4_K_M.gguf";
      sha256 = "sha256-fdVz3D4LoufWv3bhbUAM9ptq/CrljyE+TrHRM8OOk4s=";
    };
  };

  # Build one systemd unit from an instance spec
  mkUnit = inst:
    let
      # Required
      name   = inst.name or (throw "llama-cpp: each instance must set 'name'.");
      port   = toString (inst.port or (throw "llama-cpp(${name}): 'port' is required."));
      modelKey = inst.model or (throw "llama-cpp(${name}): 'model' key is required.");
      modelPath = models.${modelKey} or (throw "llama-cpp(${name}): unknown model '${modelKey}'.");

      # Defaults
      device        = inst.device or "Vulkan0";
      threads       = toString (inst.threads or 5);
      nGpuLayers    = toString (inst.nGpuLayers or 99);
      splitMode     = inst.splitMode or "none";
      chatTemplate  = inst.chatTemplate or "chatml";
      alias         = inst.alias or "${modelKey}";
      bindHost      = inst.host or "0.0.0.0";
      extraArgs     = inst.extraArgs or [];

      llamaBin = pkgs.llama-cpp;  # becomes Vulkan-enabled via overlay below
      args = [
        "--model ${modelPath}"
        "--device ${device}"
        "--split-mode ${splitMode}"
        "--threads ${threads}"
        "--chat-template ${chatTemplate}"
        "--alias ${alias}"
        "--host ${bindHost}"
        "--port ${port}"
        "--n-gpu-layers ${nGpuLayers}"
      ] ++ extraArgs;
    in
    {
      "llama-cpp-${name}" = {
        description = "llama.cpp (${name})";
        wantedBy = [ "multi-user.target" ];
        after    = [ "network-online.target" ];
        wants    = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${llamaBin}/bin/llama-server ${lib.concatStringsSep " " args}";
          Restart = "always";
          RestartSec = 2;
          DynamicUser = true;
          SupplementaryGroups = [ "video" "render" ];
          # If you ever need to avoid llvmpipe:
          # Environment = [ "VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json" ];
        };
      };
    };

  units = lib.listToAttrs (map mkUnit cfg.instances);

in
{
  options.llama-cpp.instances = lib.mkOption {
    type = with lib.types; listOf (attrsOf anything);
    default = [];
    example = [
      { name = "qwen3";   model = "qwen3-8b";   port = 8000; device = "Vulkan1"; }
      { name = "qwen25c"; model = "qwen2.5-coder-7b"; port = 8001; device = "Vulkan0"; }
    ];
    description = ''
      List of llama.cpp servers to launch. Fields:
        - name (str, required)
        - model (key, required): one of ${lib.concatStringsSep ", " (builtins.attrNames models)}
        - port (int, required)
        - device (str, default Vulkan0)
        - threads (int, default 5)
        - nGpuLayers (int, default 99)
        - splitMode (str, default "none")
        - chatTemplate (str, default "chatml")
        - alias (str, default model key)
        - host (str, default "0.0.0.0")
        - extraArgs (list of str, default [])
    '';
  };

  config = {
    # <<< The only new bit: flip Vulkan on for pkgs.llama-cpp globally >>>
    nixpkgs.overlays = [
      (final: prev: {
        llama-cpp = prev.llama-cpp.override { vulkanSupport = true; };
      })
    ];

    # Systemd units
    systemd.services = units;

    # Handy CLI tools
    environment.systemPackages = [ pkgs.llama-cpp ];
  };
}