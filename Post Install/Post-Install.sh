#!/bin/bash
# Run this after OS install. This script will install some standard packages and set up some basic configurations.

# Functions

cloneBashScripts() {
    # Clone the Bash Scripts repository
    if [ -d ~/Scripts/Bash ]; then
        echo "Bash directory already exists"
    else
        echo "Cloning Bash Scripts repository"
        mkdir -p ~/Scripts
        git clone https://github.com/cjbravo1/bash ~/Scripts/Bash
    fi
}

installGhCopilot() {
    if command -v gh >/dev/null 2>&1; then
        echo "gh is installed"
        gh auth login
        gh extension install github/gh-copilot
        gh copilot alias bash >> ~/.bashrc
    else
        echo "gh is not installed"
    fi
}

installFlatpacks() {
    flatpaks=(
        app.drey.Damask
        com.spotify.Client
        com.transmissionbt.Transmission
        org.raspberrypi.rpi-imager
        io.missioncenter.MissionCenter
    )
    # Install all flatpaks at once
    echo -e "\e[32mInstalling ${flatpaks[@]}\e[0m"  # Echo in green color
    # This command installs the Flatpaks specified in the 'flatpaks' array.
    flatpak install -y ${flatpaks[@]}
}

installGoogleChrome() {
    # Check if the OS is Ubuntu
    if [ -f /etc/debian_version ]; then
        # Check if Google Chrome is installed
        if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
            # Install Google Chrome
            echo -e "\e[32mInstalling Google Chrome\e[0m"  # Echo in green color
            wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
            sudo dpkg -i google-chrome-stable_current_amd64.deb
            sudo apt install -f -y
            rm google-chrome-stable_current_amd64.deb
        else
            echo "Google Chrome is already installed"
        fi
    fi
}

# Check if the OS is Debian-based
if [ -f /etc/debian_version ]; then
    # Start with Updates
    echo "Running: sudo apt update"
    sudo apt update
    echo "Running: sudo apt upgrade -y"
    sudo apt upgrade -y
    # Install Standard Packages
    echo "Running: sudo apt install toilet fortune lolcat vim nano htop -y"
    sudo apt install toilet fortune lolcat vim nano htop gh  -y

    # Check if Flatpak is installed
    if ! command -v flatpak >/dev/null 2>&1; then
        # Install Flatpak
        echo "Installing Flatpak"
        sudo apt install flatpak -y
        sudo apt update
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    else
        echo "Flatpak is already installed"

        # Check if the computer is a Raspberry Pi and install Cockpit for remote management
        if [ "$(uname -m)" = "armv7l" ]; then
            # Install Cockpit
            # Ask if the user wants to install Cockpit
            read -p "Do you want to install Cockpit for remote management? (y/n): " install_cockpit
            if [ "$install_cockpit" = "y" ]; then
                # Install Cockpit
                echo "Installing Cockpit"
                sudo apt install cockpit -y
                sudo systemctl enable --now cockpit.socket
                echo "Cockpit is now available at https://$(hostname -I | awk '{print $1}'):9090"
            fi
        fi
    fi

# Check if the OS is Fedora
elif [ -f /etc/redhat-release ]; then
    # Set DNF Parallel Downloads
    echo "max_parallel_downloads=10" | tee -a /etc/dnf/dnf.conf > /dev/null
    echo "fastestmirror=True" | tee -a /etc/dnf/dnf.conf > /dev/null
    dnf -y install dnf-plugins-core

    # Set DNF Default to Yes
    sudo sed -i 's/^#default_yes=default_no/default_yes=default_yes/' /etc/dnf/dnf.conf

    # Enable RPM Fusion repositories to access additional software packages and codecs
    dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    dnf group update core -y

    # Start with Updates
    echo "Running: sudo dnf makecache"
    sudo dnf makecache
    echo "Running: sudo dnf update -y"
    sudo dnf update -y

    # Install Standard Packages
    echo "Running: Standard Package Installs"
    sudo dnf install toilet fortune-mod lolcat vim nano htop google-chrome-stable gh pv fastfetch -y
    sudo dnf remove firefox libreoffice -y
fi

# Check if a desktop environment is installed
if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    # Install Flatpacks
    echo -e "\e[32mInstalling Flatpacks\e[0m"  # Echo in green color
    installFlatpacks

    # Install Google Chrome
    echo -e "\e[32mInstalling Google Chrome\e[0m"  # Echo in green color
    installGoogleChrome
fi

# Add Bashrc Greeting
if ! grep -q "Welcome to $(hostname)" ~/.bashrc; then
    echo 'echo "Welcome to $(hostname)" | toilet -f term -F border --gay' >> ~/.bashrc
fi

if ! grep -q "uptime -p" ~/.bashrc; then
    echo 'uptime -p | lolcat' >> ~/.bashrc
fi

if ! grep -q "fortune -s" ~/.bashrc; then
    echo 'fortune -s | lolcat' >> ~/.bashrc
fi

# Check if the user wants to install GitHub Copilot
read -p "Do you want to install GitHub Copilot? (y/n): " install_copilot
if [ "$install_copilot" = "y" ]; then
    installGhCopilot
fi

# Create SSH Keys
echo "Creating SSH Keys"
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< y

#Restart the shell
source ~/.bashrc

# End of Script
echo -e "\e[32End of Script\e[0m"  # Echo in green color

