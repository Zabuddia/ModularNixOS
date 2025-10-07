{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-headers
      vulkan-validation-layers
      mesa
    ];
    extraPackages32 = [
      pkgs.pkgsi686Linux.vulkan-loader
      pkgs.driversi686Linux.mesa
    ];
  };

  environment.systemPackages = with pkgs; [
    vulkan-tools  # vulkaninfo, vkcube
    radeontop
  ];
}