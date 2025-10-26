{ pkgs, ... }:
{
  hardware.amdgpu = {
    opencl.enable = true; # optional, for OpenCL apps
    initrd.enable = true;
  };

  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    rocmPackages.rocm-core
    rocmPackages.rpp
    rocmPackages.hipcc
  ];

  # (optional) expose ROCm libraries globally for apps like PyTorch, llama.cpp, etc.
  environment.variables = {
    ROCM_PATH = "${pkgs.rocmPackages.rocm-core}";
    HSA_ENABLE_SDMA = "0"; # helps avoid hangs on some GPUs
  };
}