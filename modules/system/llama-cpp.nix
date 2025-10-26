{ lib, pkgs, unstablePkgs, config, hostLLMs ? [], ... }:

let
  # Switch here (or via `llama-cpp.backend = "rocm";` in a host)
  backendDefault = "rocm";  # "vulkan" or "rocm"

  cfg = config.llama-cpp;
  backend = (cfg.backend or backendDefault);

  llamaBin =
    if backend == "rocm"
    then unstablePkgs.llama-cpp.override { rocmSupport = true; }
    else unstablePkgs.llama-cpp.override { vulkanSupport = true; };

  clineGrammarDefault = pkgs.writeText "cline.gbnf" ''
    root ::= analysis? start final .+
    analysis ::= "<|channel|>analysis<|message|>" ( [^<] | "<" [^|] | "<|" [^e] )* "<|end|>"
    start ::= "<|start|>assistant"
    final ::= "<|channel|>final<|message|>"
  '';

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

  instances = (cfg.instances or []) ++ hostLLMs;

  mkDevStr = devInt:
    if backend == "vulkan" then "Vulkan${toString devInt}" else toString devInt;

  mkUnit = inst:
    let
      rawName   = inst.name or (throw "llama-cpp: each instance must set 'name'.");
      svcName   = lib.replaceStrings [ "." " " "/" ":" "@" ] [ "-" "-" "-" "-" "-" ] rawName;
      port      = toString (inst.port or (throw "llama-cpp(${rawName}): 'port' is required."));
      modelKey  = inst.model or (throw "llama-cpp(${rawName}): 'model' is required.");
      modelPath = models.${modelKey} or (throw "llama-cpp(${rawName}): unknown model '${modelKey}'.");

      devInt    = inst.device or 0;
      devStr    = mkDevStr devInt;

      # Friendly alias for UIs (defaults to model key)
      alias     = inst.alias or modelKey;

      threads    = toString (inst.threads or 6);
      nGpuLayers = toString (inst.nGpuLayers or 999);
      ctxSize    = toString (inst.ctxSize or 24576);
      bindHost   = inst.host or "0.0.0.0";
      splitMode  = inst.splitMode or "none";
      chatTmpl   = inst.chatTemplate or "none";
      useClineGrammar = inst.useClineGrammar or false;
      extraArgs  = inst.extraArgs or [];

      # NEW: per-instance Jinja toggle (default true)
      useJinja  = if inst ? useJinja then inst.useJinja else true;

      baseArgs = [
        "--model ${modelPath}"
        "--alias ${alias}"
        "--host ${bindHost}"
        "--port ${port}"
        "--threads ${threads}"
        "--n-gpu-layers ${nGpuLayers}"
        "--ctx-size ${ctxSize}"
      ];

      args = baseArgs
        ++ lib.optionals useJinja [ "--jinja" ]
        ++ lib.optionals (backend == "vulkan") [ "--device ${devStr}" ]
        ++ lib.optionals (splitMode != "none") [ "--split-mode ${splitMode}" ]
        ++ lib.optionals (chatTmpl != "none") [ "--chat-template" chatTmpl ]
        ++ lib.optionals useClineGrammar [ "--grammar-file" "${cfg.clineGrammar}" ]
        ++ extraArgs;

      envVars = lib.optionals (backend == "rocm") [
        "HIP_VISIBLE_DEVICES=${toString devInt}"
        "ROCR_VISIBLE_DEVICES=${toString devInt}"
        "HSA_ENABLE_SDMA=0"                 # good on RX 6800 (RDNA2)
        # "HSA_OVERRIDE_GFX_VERSION=10.3.0" # only if you see an 'unsupported gfx' error
      ];
    in lib.nameValuePair "llama-cpp-${svcName}" {
      description = "llama.cpp (${rawName}) [${backend}]";
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
        Environment = envVars;
        # LimitMEMLOCK = "infinity";
        # # Only if you use strict device policies elsewhere (harmless otherwise):
        # DeviceAllow = [ "/dev/kfd rwm" "/dev/dri/renderD* rwm" ];
      };
    };

  units = lib.listToAttrs (map mkUnit instances);

in {
  options.llama-cpp = {
    backend = lib.mkOption {
      type = lib.types.enum [ "vulkan" "rocm" ];
      default = backendDefault;
      description = "Backend to build/run llama.cpp with.";
    };

    clineGrammar = lib.mkOption {
      type = lib.types.path;
      default = clineGrammarDefault;
      description = "GBNF grammar path for Cline-compatible models.";
    };

    # Minimal instance schema + optional flags (alias/split/chatTemplate/useClineGrammar/useJinja)
    instances = lib.mkOption {
      type = with lib.types; listOf (attrsOf anything);
      default = [];
      description = "llama.cpp instances (device is an integer; adapted per backend).";
    };
  };

  config = {
    systemd.services = units;
    environment.systemPackages = [ llamaBin ];
  };
}