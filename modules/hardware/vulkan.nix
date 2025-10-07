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
    extraPackages32 = with pkgs.driversi686Linux; [
      vulkan-loader
      mesa
    ];
  };

  environment.systemPackages = with pkgs; [
    vulkan-tools  # vulkaninfo, vkcube
  ];
}