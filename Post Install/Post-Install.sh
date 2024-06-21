#!/bin/bash
# Run this after OS install. This script will install some standard packages and set up some basic configurations.

# Functions
# Check if gh is installed via dnf
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

# Flatpacks
installFlatpacks() {
    flatpaks=(
        app.drey.Damask
        com.spotify.Client
        com.transmissionbt.Transmission
        org.raspberrypi.rpi-imager
    )
    for flatpak in "${flatpaks[@]}"; do
        echo -e "\e[32mInstalling $flatpak\e[0m"  # Echo in green color
        flatpak install -y $flatpak
    done
}

# Google Chrome for Ubuntu
installGoogleChrome() {
    # Check if the OS is Ubuntu
    if [ "$(lsb_release -si)" = "Ubuntu" ]; then
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
    fi

# Check if the OS is Fedora
elif [ -f /etc/redhat-release ];; then
    # Set DNF Parallel Downloads
    echo "Running: sudo sed -i 's/^max_parallel_downloads=.*/max_parallel_downloads=10/' /etc/dnf/dnf.conf"
    sudo sed -i 's/^max_parallel_downloads=.*/max_parallel_downloads=10/' /etc/dnf/dnf.conf

    # Set DNF Default to Yes
    echo "Running: sudo sed -i 's/^#default_yes=default_no/default_yes=default_yes/' /etc/dnf/dnf.conf"
    sudo sed -i 's/^#default_yes=default_no/default_yes=default_yes/' /etc/dnf/dnf.conf

    # Start with Updates
    echo "Running: sudo dnf makecache"
    sudo dnf makecache
    echo "Running: sudo dnf update -y"
    sudo dnf update -y
    # Install Standard Packages
    echo "Running: Standard Package Installs"
    sudo dnf install toilet fortune-mod lolcat vim nano htop google-chrome-stable gh pv -y
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
echo 'echo "Welcome to $(hostname)" | toilet -f term -F border --gay' >> ~/.bashrc
echo 'uptime -p | lolcat' >> ~/.bashrc
echo 'fortune -s | lolcat' >> ~/.bashrc

# Check if the user wants to install GitHub Copilot
read -p "Do you want to install GitHub Copilot? (y/n): " install_copilot
if [ "$install_copilot" = "y" ]; then
    installGhCopilot
fi

# Create SSH Keys
echo "Creating SSH Keys"
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< y

echo -e "\e[32End of Script\e[0m"  # Echo in green color]"
