#!/bin/bash

echo "\n\e[36m=== arch-bootstrapper ===\n\e[0m"
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
read -p "$(echo -e '\n\e[32mDo you want to set the below options in /etc/pacman.conf?\n\n\e[33m(Color, VerbosePkgLists, ILoveCandy, ParallelDownloads = 10)\n\n\e[35mEnter your choice (Y/n):\e[0m ') " configure_pacman
configure_pacman=${configure_pacman:-Y}

if [[ $configure_pacman =~ ^[Yy]$ ]]; then
    echo -e "\n\e[32mConfiguring pacman...\e[0m"
    sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf
    sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' /etc/pacman.conf
    sudo sed -i 's/^#ParallelDownloads = 5$/ParallelDownloads = 10/' /etc/pacman.conf
    sudo sed -i 's/^ParallelDownloads = 5$/ParallelDownloads = 10/' /etc/pacman.conf
    if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
        sudo sed -i '/^VerbosePkgLists/a ILoveCandy' /etc/pacman.conf
    fi
fi

# Ask about reflector
echo
echo -e "\n\e[32mDo you want to install and run reflector to generate a fast mirror list?\e[0m"
echo -e "\n\e[33m(sudo reflector --country <COUNTRY_CODE> --score 20 --sort rate --save /etc/pacman.d/mirrorlist)\e[0m\n"
echo -e "1) \e[36mInstall and run now\e[0m (automatically detects country from timezone/locale)"
echo -e "2) \e[36mInstall but don't run right now\e[0m"
echo -e "n) \e[36mDon't install\e[0m"
read -p "$(echo -e '\n\e[35mEnter your choice (1-3):\e[0m ') " reflector_choice

case $reflector_choice in
    1)
        echo -e "\n\e[32mInstalling reflector...\e[0m\n"
        sudo pacman -S --needed --noconfirm reflector rsync
        echo -e "\n\e[32mUpdating mirrorlist with reflector...\e[0m\n"
        
        # Detect country from locale
        COUNTRY_CODE=$(locale | grep -oP '^LC_TIME=.*_\K[A-Z]{2}' | head -1)
        if [ -z "$COUNTRY_CODE" ]; then
            COUNTRY_CODE=$(locale | grep -oP '^LANG=.*_\K[A-Z]{2}' | head -1)
        fi
        COUNTRY_CODE=${COUNTRY_CODE:-US}
        
        echo -e "\e[33mDetected country: $COUNTRY_CODE\e[0m\n"
        sudo reflector --country "$COUNTRY_CODE" --score 20 --sort rate --save /etc/pacman.d/mirrorlist
        ;;
    2)
        echo -e "\n\e[32mInstalling reflector...\e[0m\n"
        sudo pacman -S --needed --noconfirm reflector rsync
        ;;
    n|N)
        echo -e "\n\e[32mSkipping reflector installation.\e[0m\n"
        ;;
esac

# Ask about base TUI packages
echo
read -p "$(echo -e '\n\e[32mDo you want to install base TUI packages?\n\n\e[33m(sudo pacman -S --needed --noconfirm jq socat nano git github-cli wget unzip zsh yazi dysk bat btop cifs-utils fastfetch ffmpeg fzf base-devel)\n\n\e[35mEnter your choice (Y/n):\e[0m ') " install_base
install_base=${install_base:-Y}

if [[ $install_base =~ ^[Yy]$ ]]; then
    echo -e "\n\e[32mInstalling base TUI packages...\e[0m\n"
    if ! sudo pacman -S --needed --noconfirm jq socat nano git github-cli wget unzip zsh yazi dysk bat btop cifs-utils fastfetch ffmpeg fzf base-devel; then
        echo -e "\n\e[31mError: Failed to install base TUI packages\e[0m\n"
        exit 1
    fi
fi

# Ask about kernel headers
echo
read -p "$(echo -e '\n\e[32mDo you want to install kernel headers?\n\n\e[33m(Automatically detects appropriate headers package for installed kernels: linux, linux-zen, linux-lts, linux-hardened)\n\n\e[31mNOTE: Kernel headers are necessary for nvidia-dkms!\n\n\e[35mEnter your choice (Y/n):\e[0m ') " install_headers
install_headers=${install_headers:-Y}

if [[ $install_headers =~ ^[Yy]$ ]]; then
    echo -e "\n\e[32mInstalling kernel headers...\e[0m\n"
    
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
fi

# Ask about AUR helper
echo
echo -e "\n\e[32mWhich AUR helper do you want to install?\e[0m\n"
echo -e "1) \e[36myay\e[0m"
echo -e "2) \e[36mparu\e[0m"
read -p "$(echo -e '\n\e[35mEnter your choice (1-2):\e[0m ') " aur_choice

case $aur_choice in
    1)
        AUR_HELPER="yay"
        if ! command -v yay &> /dev/null; then
            echo -e "\n\e[32mInstalling yay...\e[0m\n"
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
            echo -e "\n\e[33myay already installed\e[0m\n"
        fi
        ;;
    2)
        AUR_HELPER="paru"
        if ! command -v paru &> /dev/null; then
            echo -e "\n\e[32mInstalling paru...\e[0m\n"
            if ! git clone https://aur.archlinux.org/paru.git /tmp/paru; then
                echo -e "\n\e[31mError: Failed to clone paru repository\e[0m\n"
                exit 1
            fi
            cd /tmp/paru
            if ! makepkg -si --noconfirm; then
                cd -
                echo -e "\n\e[31mError: Failed to build/install paru\e[0m\n"
                exit 1
            fi
            cd -
        else
            echo -e "\n\e[33mparu already installed\e[0m\n"
        fi
        ;;
esac

# Ask about GPU type
echo
echo -e "\n\e[32mWhich type of GPU do you have?\e[0m\n"
echo -e "1) \e[36mNVIDIA\e[0m\n(Choose between open-source and proprietary drivers in the next step)\n\e[0m"
echo -e "2) \e[36mAMD\n\e[33m(${AUR_HELPER:-pacman} -S --needed --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader)\n\e[0m"
echo -e "3) \e[36mIntel\n\e[33m(${AUR_HELPER:-pacman} -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader)\n\e[0m"
echo -e "4) \e[36mSkip GPU driver installation\e[0m\n"
read -p "$(echo -e '\e[35mEnter your choice (1-4):\e[0m ') " gpu_choice

case $gpu_choice in
    1)
        echo
        echo -e "\n\e[32mWhich NVIDIA GPU series do you have?\e[0m\n"
        echo -e "1) \e[36mGeForce 16 series and newer\n\e[33m(${AUR_HELPER:-pacman} -S --needed --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader)\n\e[0m"
        echo -e "2) \e[36mGeForce 10 series and older\n\e[33m(${AUR_HELPER:-pacman} -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader)\n\e[0m"
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
                ${AUR_HELPER:-sudo pacman} -S --needed --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader
                ;;
            2)
                echo -e "\n\e[32mInstalling NVIDIA drivers (proprietary)...\e[0m\n"
                ${AUR_HELPER:-sudo pacman} -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader
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
        ${AUR_HELPER:-sudo pacman} -S --needed --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader
        ;;
    3)
        # Check if multilib is enabled (needed for 32-bit libs)
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            echo -e "\n\e[32mEnabling multilib repository for 32-bit GPU libraries...\e[0m\n"
            sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
            sudo pacman -Sy
        fi
        
        echo -e "\n\e[32mInstalling Intel drivers...\e[0m\n"
        ${AUR_HELPER:-sudo pacman} -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader
        ;;
esac

# Ask about desktop packages
echo
read -p "$(echo -e '\e[32mDo you want to install hyprland along with additional desktop packages?\n\n\e[33m('${AUR_HELPER:-pacman}' -S --needed --noconfirm bluez bluez-libs bluez-utils pipewire pipewire-pulse wireplumber cava swayimg celluloid dunst firefox hyprland hyprlock hyprpicker polkit-gnome gnome-keyring swww nautilus wofi grim slurp wl-clipboard wl-clip-persist xdg-desktop-portal xdg-desktop-portal-hyprland xorg-xwayland ly inter-font kitty nwg-look brightnessctl obs-studio openssh sassc ttf-jetbrains-mono-nerd neovim visual-studio-code-bin playerctl waybar wine-staging wine-mono winetricks flatpak steam)\n\n\e[35mEnter your choice (Y/n):\e[0m ') " install_desktop
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
    ${AUR_HELPER:-sudo pacman} -Syu --noconfirm
    
    ((DESKTOP_CURRENT++))
    echo -e "\n\e[32m[$DESKTOP_CURRENT/$DESKTOP_STEPS] Installing desktop packages...\e[0m\n"
    ${AUR_HELPER:-sudo pacman} -S --needed --noconfirm bluez bluez-libs bluez-utils pipewire pipewire-pulse wireplumber cava swayimg celluloid dunst firefox hyprland hyprlock hyprpicker polkit-gnome gnome-keyring swww nautilus wofi grim slurp wl-clipboard wl-clip-persist xdg-desktop-portal xdg-desktop-portal-hyprland xorg-xwayland ly inter-font kitty nwg-look obs-studio openssh sassc ttf-jetbrains-mono-nerd visual-studio-code-bin playerctl waybar wine-staging wine-mono winetricks flatpak steam
fi

# Ask about device type
echo
echo -e "\n\e[32mIs this machine a desktop, or is it a laptop?\e[0m"
echo -e "\n\e[33mLaptop option installs TLP for power management\e[0m\n"
echo -e "1) \e[36mDesktop\e[0m"
echo -e "2) \e[36mLaptop\e[0m"
read -p "$(echo -e '\n\e[35mEnter your choice (1 or 2):\e[0m ') " device_type

case $device_type in
    2)
        echo -e "\n\e[32mInstalling TLP for laptop power management...\e[0m\n"
        ${AUR_HELPER:-sudo pacman} -S --needed --noconfirm tlp
        sudo systemctl enable --now tlp
        ;;
    *)
        echo -e "\e[32mSkipping laptop-specific packages.\e[0m\n"
        ;;
esac

# Ask about installing dotfiles
echo
read -p "$(echo -e '\n\e[32mDo you want to install Chris'\''s dotfiles?\n\n\e[33m(Includes configs and Tokyo Night theming for GTK, hyprland, hyprlock, waybar, dunst, wofi, nano, kitty, btop, cava and fastfetch, along with Tokyo Night icons)\n\n\e[35mEnter your choice (Y/n):\e[0m ') " install_dotfiles
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
        
        # If paru was chosen, replace yay with paru in .zshrc
        if [[ $AUR_HELPER == "paru" ]] && [ -f "$HOME/.zshrc" ]; then
            echo -e "\n\e[32mUpdating .zshrc to use paru instead of yay...\e[0m\n"
            sed -i 's/yay/paru/g' "$HOME/.zshrc"
        fi
        
        # Create VS Code settings
        code --install-extension enkia.tokyo-night
        mkdir -p "$HOME/.config/Code/User"
        cat > "$HOME/.config/Code/User/settings.json" << 'EOF'
{
    "editor.minimap.enabled": false,
    "editor.fontFamily": "'JetBrainsMono Nerd Font'",
    "editor.stickyScroll.enabled": false,
    "window.menuBarVisibility": "compact",
    "breadcrumbs.enabled": false,
    "workbench.colorTheme": "Tokyo Night"
}
EOF
        
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
    
    # If laptop was chosen, uncomment battery module in waybar config
    if [[ $device_type == "2" ]]; then
        if [ -f "$HOME/.config/waybar/config.jsonc" ]; then
            echo -e "\n\e[32mEnabling battery module in waybar...\e[0m\n"
            sed -i 's|^[[:space:]]*// "battery",|        "battery",|' "$HOME/.config/waybar/config.jsonc"
        fi
    fi
    
    # Configure waybar temperature sensor path
    if [ -f "$HOME/.config/waybar/config.jsonc" ]; then
        echo -e "\n\e[32mConfiguring waybar temperature sensor...\e[0m\n"
        # Find the correct hwmon path for CPU package temperature
        TEMP_PATH=$(for i in /sys/class/hwmon/hwmon*/temp*_input; do 
            name=$(cat "$(dirname "$i")/name" 2>/dev/null)
            label=$(cat "${i%_*}_label" 2>/dev/null)
            if [[ "$name" == "coretemp" ]] || [[ "$name" == "k10temp" ]] || [[ "$name" == "zenpower" ]]; then
                if [[ "$label" == "Package id 0" ]] || [[ "$label" == "Tdie" ]] || [[ "$label" == "Tctl" ]] || [[ -z "$label" ]]; then
                    echo "$i"
                    break
                fi
            fi
        done)
        
        if [ -n "$TEMP_PATH" ]; then
            sed -i "s|\"hwmon-path\": \".*\"|\"hwmon-path\": \"$TEMP_PATH\"|" "$HOME/.config/waybar/config.jsonc"
            echo -e "\e[33mTemperature sensor configured: $TEMP_PATH\e[0m"
        else
            echo -e "\e[33mWarning: Could not automatically detect CPU temperature sensor path\e[0m"
        fi
    fi
    sudo rm /usr/share/wayland-sessions/hyprland-uwsm.desktop
    sudo systemctl enable ly
    mkdir -p "$HOME/Screenshots"
    
    echo -e "\e[32mSetting default shell to zsh...\e[0m\n"
    chsh -s /usr/bin/zsh
fi

echo
echo -e "\n\e[32m=== Installation complete!\e[0m\n"

echo -e "\e[31m=== It is recommended to reboot your system to apply all changes\e[0m\n"
