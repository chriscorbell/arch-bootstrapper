# arch-bootstrapper
A bash utility for bootstrapping a new minimal installation of Arch Linux with common packages and configs (and optional [dotfiles](https://github.com/chriscorbell/dotfiles) installation), specifically meant to be ran after using archinstall without any profile.

It's like a simpler Omarchy **with less opinions**.

# What arch-bootstrapper can do
  - Set prettifying options in `/etc/pacman.conf` and increase parallelism to 10
  - Install reflector & rsync then run `sudo reflector --country US --score 20 --sort rate --save /etc/pacman.d/mirrorlist`
  - Install base TUI packages ```jq socat nano git github-cli wget curl unzip zsh yazi dysk bat btop cifs-utils fastfetch ffmpeg fzf base-devel```
  - Install appropriate kernel headers
  - Install AUR helper (choose either [yay](https://github.com/Jguer/yay) or [paru](https://github.com/Morganamilo/paru))
  - Install appropriate GPU packages
  - Install [hyprland](https://github.com/hyprwm/Hyprland) and related packages for desktop scenario: ```luez bluez-libs bluez-utils pipewire pipewire-pulse wireplumber cava celluloid dunst firefox hyprland hyprlock swww nautilus wofi grim slurp wl-clipboard wl-clip-persist xdg-desktop-portal xdg-desktop-portal-hyprland xorg-xwayland ly inter-font kitty nwg-look obs-studio openssh sassc ttf-jetbrains-mono-nerd visual-studio-code-bin playerctl waybar wine-staging wine-mono winetricks flatpak steam``` then enables service for `ly` display manager
  - Choose Laptop or Desktop - Laptop installs TLP and enables its service
  - Install [my dotfiles](https://github.com/chriscorbell/dotfiles)

# Less opinions?
Yes, it asks for confirmation for each step, **and tells you exactly what it will do before it does it**.
If you see something you don't like, just hit "n".