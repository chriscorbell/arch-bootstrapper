#!/bin/bash

echo "=== Arch Linux Dependencies Installer ==="
echo

# Ask about passwordless sudo
read -p "$(echo -e "\n\e[32mDo you want to enable passwordless sudo for your user?\n\n\e[33m(Creates \"%wheel ALL=(ALL:ALL) NOPASSWD: ALL\" override in /etc/sudoers.d/00_$USER)\n\n\e[35mEnter your choice (Y/n):\e[0m ") " enable_passwordless_sudo
enable_passwordless_sudo=${enable_passwordless_sudo:-Y}

if [[ $enable_passwordless_sudo =~ ^[Yy]$ ]]; then
    echo -e "\n\e[32mEnabling passwordless sudo...\e[0m\n"
    # Check if there's already a user-specific override from archinstall
    if [ -f "/etc/sudoers.d/00_$USER" ]; then
        # Check if NOPASSWD is already set (uncommented)
        if grep -q "^[^#]*%wheel.*NOPASSWD" "/etc/sudoers.d/00_$USER"; then
            echo -e "\e[33mNOPASSWD already enabled in /etc/sudoers.d/00_$USER\e[0m"
        else
            # Update existing file to add NOPASSWD (handles both commented and uncommented lines)
            sudo sed -i "s/^#[[:space:]]*%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/" "/etc/sudoers.d/00_$USER"
            sudo sed -i "s/^#[[:space:]]*%wheel ALL=(ALL) ALL/%wheel ALL=(ALL) NOPASSWD: ALL/" "/etc/sudoers.d/00_$USER"
            sudo sed -i "s/^%wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/" "/etc/sudoers.d/00_$USER"
            sudo sed -i "s/^%wheel ALL=(ALL) ALL$/%wheel ALL=(ALL) NOPASSWD: ALL/" "/etc/sudoers.d/00_$USER"
        fi
    else
        # Create new sudoers override file in /etc/sudoers.d/
        echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/wheel-nopasswd > /dev/null
        sudo chmod 440 /etc/sudoers.d/wheel-nopasswd
    fi
fi

# Ask about pacman configuration
read -p "$(echo -e '\n\e[32mDo you want to set prettifying options in /etc/pacman.conf?\n\n\e[33m(Color, VerbosePkgLists, ILoveCandy)\n\n\e[35mEnter your choice (Y/n):\e[0m ') " configure_pacman
configure_pacman=${configure_pacman:-Y}

if [[ $configure_pacman =~ ^[Yy]$ ]]; then
    echo -e "\n\e[32mConfiguring pacman...\e[0m"
    sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf
    sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' /etc/pacman.conf
    if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
        sudo sed -i '/^VerbosePkgLists/a ILoveCandy' /etc/pacman.conf
    fi
fi

# Faster mirrors
sudo pacman -Syu reflector rsync
echo -e "\n\e[32mUpdating mirrorlist with reflector...\e[0m\n"
sudo reflector --country US --score 20 --sort rate --save /etc/pacman.d/mirrorlist

# Install base dependencies
TOTAL_STEPS=4
CURRENT_STEP=0

((CURRENT_STEP++))
echo -e "\n\e[32m[$CURRENT_STEP/$TOTAL_STEPS] Installing base dependencies...\e[0m\n"
if ! sudo pacman -S --needed --noconfirm jq socat nano git github-cli wget curl unzip zsh yazi bat btop cifs-utils fastfetch ffmpeg fzf base-devel rust; then
    echo -e "\n\e[31mError: Failed to install base dependencies\e[0m\n"
    exit 1
fi

# Install kernel headers
((CURRENT_STEP++))
echo -e "\n\e[32m[$CURRENT_STEP/$TOTAL_STEPS] Installing kernel headers...\e[0m\n"

if pacman -Q linux &> /dev/null; then
    sudo pacman -S --needed --noconfirm linux-headers
fi

if pacman -Q linux-zen &> /dev/null; then
    sudo pacman -S --needed --noconfirm linux-zen-headers
fi

if pacman -Q linux-lts &> /dev/null; then
    sudo pacman -S --needed --noconfirm linux-lts-headers
fi

if pacman -Q linux-hardened &> /dev/null; then
    sudo pacman -S --needed --noconfirm linux-hardened-headers
fi

# Install yay if not already installed
((CURRENT_STEP++))
if ! command -v yay &> /dev/null; then
    echo -e "\n\e[32m[$CURRENT_STEP/$TOTAL_STEPS] Installing yay...\e[0m\n"
    if ! git clone https://aur.archlinux.org/yay.git /tmp/yay; then
        echo -e "\n\e[31mError: Failed to clone yay repository\e[0m\n"
        exit 1
    fi
    cd /tmp/yay
    if ! makepkg -si --noconfirm; then
        cd -
        echo -e "\n\e[31mError: Failed to build/install yay\e[0m\n"
        exit 1
    fi
    cd -
else
    echo -e "\n\e[33m[$CURRENT_STEP/$TOTAL_STEPS] yay already installed\e[0m\n"
fi

# Install dysk
((CURRENT_STEP++))
echo -e "\n\e[32m[$CURRENT_STEP/$TOTAL_STEPS] Installing dysk...\e[0m\n"
if ! cargo install --locked dysk; then
    echo -e "\n\e[31mError: Failed to install dysk\e[0m\n"
    exit 1
fi

# Ask about GPU type
echo
echo -e "\n\e[32mWhich type of GPU do you have?\e[0m\n"
echo -e "1) \e[36mNVIDIA\e[0m\n(Choose between open-source and proprietary drivers in the next step)\n\e[0m"
echo -e "2) \e[36mAMD\n\e[33m(yay -S --needed --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader)\n\e[0m"
echo -e "3) \e[36mIntel\n\e[33m(yay -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader)\n\e[0m"
echo -e "4) \e[36mSkip GPU driver installation\e[0m\n"
read -p "$(echo -e '\e[35mEnter your choice (1-4):\e[0m ') " gpu_choice

case $gpu_choice in
    1)
        echo
        echo -e "\n\e[32mWhich NVIDIA GPU series do you have?\e[0m\n"
        echo -e "1) \e[36mGeForce 16 series and newer\n\e[33m(yay -S --needed --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader)\n\e[0m"
        echo -e "2) \e[36mGeForce 10 series and older\n\e[33m(yay -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader)\n\e[0m"
        read -p "$(echo -e '\e[35mEnter your choice (1 or 2):\e[0m ') " nvidia_choice
        
        # Check if multilib is enabled (needed for 32-bit libs)
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            echo -e "\n\e[32mEnabling multilib repository for 32-bit GPU libraries...\e[0m\n"
            sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
            sudo pacman -Sy
        fi
        
        case $nvidia_choice in
            1)
                echo -e "\n\e[32mInstalling NVIDIA drivers (open-source)...\e[0m\n"
                yay -S --needed --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader
                ;;
            2)
                echo -e "\n\e[32mInstalling NVIDIA drivers (proprietary)...\e[0m\n"
                yay -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader
                ;;
        esac
        ;;
    2)
        # Check if multilib is enabled (needed for 32-bit libs)
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            echo -e "\n\e[32mEnabling multilib repository for 32-bit GPU libraries...\e[0m\n"
            sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
            sudo pacman -Sy
        fi
        
        echo -e "\n\e[32mInstalling AMD drivers...\e[0m\n"
        yay -S --needed --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader
        ;;
    3)
        # Check if multilib is enabled (needed for 32-bit libs)
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            echo -e "\n\e[32mEnabling multilib repository for 32-bit GPU libraries...\e[0m\n"
            sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
            sudo pacman -Sy
        fi
        
        echo -e "\n\e[32mInstalling Intel drivers...\e[0m\n"
        yay -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader
        ;;
esac

# Ask about desktop packages
echo
read -p "$(echo -e '\e[32mDo you want to install additional packages for desktop use?\n\n\e[33m(yay -S --needed --noconfirm bluez bluez-libs bluez-utils pipewire pipewire-pulse wireplumber cava swayimg celluloid dunst firefox hyprland hyprlock polkit-gnome gnome-keyring swww nautilus wofi grim slurp wl-clipboard wl-clip-persist xdg-desktop-portal xdg-desktop-portal-hyprland xorg-xwayland ly inter-font kitty nwg-look obs-studio openssh sassc ttf-jetbrains-mono-nerd visual-studio-code-bin playerctl waybar wine-staging wine-mono winetricks flatpak steam)\n\n\e[35mEnter your choice (Y/n):\e[0m ') " install_desktop
install_desktop=${install_desktop:-Y}

if [[ $install_desktop =~ ^[Yy]$ ]]; then
    DESKTOP_STEPS=3
    DESKTOP_CURRENT=0
    
    # Check if multilib is already enabled
    ((DESKTOP_CURRENT++))
    echo -e "\n\e[32m[$DESKTOP_CURRENT/$DESKTOP_STEPS] Enabling multilib repository...\e[0m\n"
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    fi
    
    ((DESKTOP_CURRENT++))
    echo -e "\n\e[32m[$DESKTOP_CURRENT/$DESKTOP_STEPS] Updating package lists...\e[0m\n"
    yay -Syu --noconfirm
    
    ((DESKTOP_CURRENT++))
    echo -e "\n\e[32m[$DESKTOP_CURRENT/$DESKTOP_STEPS] Installing desktop packages...\e[0m\n"
    yay -S --needed --noconfirm bluez bluez-libs bluez-utils pipewire pipewire-pulse wireplumber cava swayimg celluloid dunst firefox hyprland hyprlock polkit-gnome gnome-keyring swww nautilus wofi grim slurp wl-clipboard wl-clip-persist xdg-desktop-portal xdg-desktop-portal-hyprland xorg-xwayland ly inter-font kitty nwg-look obs-studio openssh sassc ttf-jetbrains-mono-nerd visual-studio-code-bin playerctl waybar wine-staging wine-mono winetricks flatpak steam
fi

# Ask about installing dotfiles
echo
read -p "$(echo -e '\n\e[32mDo you want to install Chris Corbell'\''s dotfiles?\n\n\e[33m(Includes Tokyo Night theme for various applications, this step also installs Tokyo Night GTK theme + icons)\n\n\e[35mEnter your choice (Y/n):\e[0m ') " install_dotfiles
install_dotfiles=${install_dotfiles:-Y}

if [[ $install_dotfiles =~ ^[Yy]$ ]]; then
    echo -e "\n\e[32mInstalling dotfiles...\e[0m\n"
    # Clone the repo to a temporary directory
    TEMP_DIR=$(mktemp -d)
    if git clone https://github.com/chriscorbell/dotfiles "$TEMP_DIR"; then
        # Copy all files including hidden ones to home directory
        cp -r "$TEMP_DIR"/. "$HOME/"
        # Remove the .git directory
        rm -rf "$HOME/.git"
        # Clean up temp directory
        rm -rf "$TEMP_DIR"
        echo -e "\n\e[32mDotfiles installed successfully!\e[0m\n"
    else
        echo -e "\n\e[31mError: Failed to clone dotfiles repository\e[0m\n"
        rm -rf "$TEMP_DIR"
    fi
    
    # Install Tokyo Night GTK theme and icons
    echo -e "\n\e[32mInstalling Tokyo Night GTK theme and icons...\e[0m\n"
    THEME_DIR=$(mktemp -d)
    if git clone https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme "$THEME_DIR"; then
        # Install GTK theme
        cd "$THEME_DIR/themes"
        chmod +x install.sh
        ./install.sh -t purple -c dark -s compact -l
        cd -
        
        # Install icons
        mkdir -p "$HOME/.icons"
        cp -r "$THEME_DIR/icons/Tokyonight-Moon" "$HOME/.icons/"
        
        # Clean up
        rm -rf "$THEME_DIR"
        echo -e "\n\e[32mTokyo Night GTK theme and icons installed successfully!\e[0m\n"
    else
        echo -e "\n\e[31mError: Failed to clone Tokyo Night GTK theme repository\e[0m\n"
        rm -rf "$THEME_DIR"
    fi
    
    # Configure ly display manager
    echo -e "\n\e[32mConfiguring ly display manager...\e[0m\n"
    sudo sed -i 's/^allow_empty_password = true/allow_empty_password = false/' /etc/ly/config.ini
    sudo sed -i 's/^animation = none/animation = colormix/' /etc/ly/config.ini
    sudo sed -i 's/^bg = 0x00000000/bg = 0x001A1B26/' /etc/ly/config.ini
    sudo sed -i 's/^blank_box = true/blank_box = false/' /etc/ly/config.ini
    sudo sed -i 's/^border_fg = 0x00FFFFFF/border_fg = 0x00A9B1D6/' /etc/ly/config.ini
    sudo sed -i 's/^clear_password = false/clear_password = true/' /etc/ly/config.ini
    sudo sed -i 's/^clock = null/clock = %I:%M %p/' /etc/ly/config.ini
    sudo sed -i 's/^colormix_col1 = 0x00FF0000/colormix_col1 = 0x001A1B26/' /etc/ly/config.ini
    sudo sed -i 's/^colormix_col2 = 0x00FF0000/colormix_col2 = 0x007AA2F7/' /etc/ly/config.ini
    sudo sed -i 's/^colormix_col3 = 0x00FF0000/colormix_col3 = 0x00AD8EE6/' /etc/ly/config.ini
    sudo sed -i 's/^error_bg = 0x00000000/error_bg = 0x00F7768E/' /etc/ly/config.ini
    sudo sed -i 's/^error_fg = 0x01FF0000/error_fg = 0x011A1B26/' /etc/ly/config.ini
    sudo sed -i 's/^fg = 0x00FFFFFF/fg = 0x00A9B1D6/' /etc/ly/config.ini
fi

sudo rm /usr/share/wayland-sessions/hyprland-uwsm.desktop
sudo systemctl enable ly

echo
echo -e "\n\e[32m=== Installation complete!\e[0m\n"
echo -e "\e[35m=== Zsh was installed, run "chsh -s $(which zsh)" to set it as your default shell\e[0m\n"
echo -e "\e[31m=== It is recommended to reboot your system to apply all changes\e[0m\n"
