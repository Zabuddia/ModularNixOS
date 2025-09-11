# How to install NixOS
- Put NixOS on a USB drive and go thorugh installation
## Connect to the internet
## Install Git
```bash
nix-shell -p git
```
## Set Up GitHub
```bash
ssh-keygen -t ed25519 -C "fife.alan@protonmail.com"
cat ~/.ssh/id_ed25519.pub 
# Paste this into GitHub
mkdir ~/.nixos
git clone git@github.com:Zabuddia/ModularNixOS.git ~/.nixos
```
## Set Up NixOS
- Edit hosts.nix and users-list.nix in the modules/config/ directory to be what you want
```bash
sudo cp /etc/nixos/hardware-configuration.nix ~/.nixos/hosts/<your-hostname>-hardware.nix
cd ~/.nixos
sudo nixos-rebuild switch --flake .#<your-hostname>
```
