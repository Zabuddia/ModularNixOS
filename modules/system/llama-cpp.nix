{ lib, pkgs, config, hostLLMs ? [], ... }:

let
  cfg = config.llama-cpp;

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
      sha256 = "sha256-wnU2ZA5BADKGXcaHgdgKCLmPjbXpNXWRmvjMwFaK608=";
    };
    "openhands-lm-7b" = pkgs.fetchurl {
      url = "https://huggingface.co/bartowski/all-hands_openhands-lm-7b-v0.1-GGUF/resolve/main/all-hands_openhands-lm-7b-v0.1-Q5_K_M.gguf";
      sha256 = "sha256-zUwlYk002h/RGYKHirSB1bko4GJJTFjUoSgtaoW6DDo=";
    };
  };

  # merge instances: module option + host-supplied list
  instances = (cfg.instances or []) ++ hostLLMs;

  mkUnit = inst:
    let
      rawName  = inst.name or (throw "llama-cpp: each instance must set 'name'.");
      svcName  = lib.replaceStrings [ "." " " "/" ":" "@" ] [ "-" "-" "-" "-" "-" ] rawName;
      port     = toString (inst.port or (throw "llama-cpp(${rawName}): 'port' is required."));
      modelKey = inst.model or (throw "llama-cpp(${rawName}): 'model' is required.");
      modelPath = models.${modelKey} or (throw "llama-cpp(${rawName}): unknown model '${modelKey}'.");

      device      = inst.device or "Vulkan0";
      threads     = toString (inst.threads or 5);
      nGpuLayers  = toString (inst.nGpuLayers or 99);
      splitMode   = inst.splitMode or "none";
      chatTmpl    = inst.chatTemplate or "chatml";
      alias       = inst.alias or "${modelKey}";
      bindHost    = inst.host or "0.0.0.0";
      extraArgs   = inst.extraArgs or [];

      llamaBin = pkgs.llama-cpp; # Vulkan-enabled via overlay below
      args = [
        "--model ${modelPath}"
        "--device ${device}"
        "--split-mode ${splitMode}"
        "--threads ${threads}"
        "--chat-template ${chatTmpl}"
        "--alias ${alias}"
        "--host ${bindHost}"
        "--port ${port}"
        "--n-gpu-layers ${nGpuLayers}"
        "--jinja"
      ] ++ extraArgs;

      unitValue = {
        description = "llama.cpp (${rawName})";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "network-online.target" ];
        wants       = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${llamaBin}/bin/llama-server ${lib.concatStringsSep " " args}";
          Restart = "always";
          RestartSec = 2;
          DynamicUser = true;
          SupplementaryGroups = [ "video" "render" ];
          # Environment = [ "VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json" ];
        };
      };
    in lib.nameValuePair "llama-cpp-${svcName}" unitValue;

  units = lib.listToAttrs (map mkUnit instances);

in {
  options.llama-cpp.instances = lib.mkOption {
    type = with lib.types; listOf (attrsOf anything);
    default = [];
    description = "Additional llama.cpp instances (merged with hostLLMs).";
  };

  config = {
    # enable Vulkan in pkgs.llama-cpp
    nixpkgs.overlays = [
      (final: prev: {
        llama-cpp = prev.llama-cpp.override { vulkanSupport = true; };
      })
    ];

    systemd.services = units;
    environment.systemPackages = [ pkgs.llama-cpp ];
  };
}