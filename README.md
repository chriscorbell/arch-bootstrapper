# arch-bootstrapper
A simple bash script for setting up a new installation of Arch Linux

# What this script does
1) Set options in `/etc/pacman.conf`
2) Install ```jq socat nano git github-cli wget curl unzip zsh yazi bat btop cifs-utils fastfetch ffmpeg fzf base-devel rust```
3) Install appropriate kernel headers
4) Install yay
5) Install dysk using cargo
6) Install appropriate GPU packages
7) Optionally install hyprland and related packages for desktop scenario: ```luez bluez-libs bluez-utils pipewire pipewire-pulse wireplumber cava celluloid dunst firefox hyprland hyprlock swww nautilus wofi grim slurp wl-clipboard wl-clip-persist xdg-desktop-portal xdg-desktop-portal-hyprland xorg-xwayland ly inter-font kitty nwg-look obs-studio openssh sassc ttf-jetbrains-mono-nerd visual-studio-code-bin playerctl waybar wine-staging wine-mono winetricks flatpak steam```
8) Optionally install my dotfiles
