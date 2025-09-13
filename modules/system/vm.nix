{ config, pkgs, lib, ... }:

{
  # Load KVM (Intel or AMD — the unused one is ignored)
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];

  # Libvirt + QEMU/KVM
  virtualisation.libvirtd.enable = true;

  # GUI manager (virt-manager)
  programs.virt-manager.enable = true;

environment.systemPackages = with pkgs; [
    quickemu
    quickgui
    virtio-win         # VirtIO driver ISO for Windows guests
    spice-gtk          # clipboard, display integration
    spice-protocol
    swtpm              # TPM for Windows 11
    OVMF               # UEFI firmware for VMs
  ];
}