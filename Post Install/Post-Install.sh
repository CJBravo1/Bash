#!/bin/bash
#Run this after OS install. This script will install some standard packages and set up some basic configurations.

# Check if the OS is Debian-based
if [ "$(lsb_release -si)" = "Debian" ] || [ "$(lsb_release -si)" = "Ubuntu" ]; then
    #Start with Updates
    echo "Running: sudo apt update"
    sudo apt update 
    echo "Running: sudo apt upgrade -y"
    sudo apt upgrade -y 
    # Install Standard Packages
    echo "Running: sudo apt install toilet fortune lolcat vim nano htop cockpit -y"
    sudo apt install toilet fortune lolcat vim nano htop cockpit -y

fi

# Check if the OS is Fedora
if [ "$(lsb_release -si)" = "Fedora" ]; then
    # Set DNF Parallel Downloads
    echo "Running: sudo sed -i 's/^max_parallel_downloads=.*/max_parallel_downloads=10/' /etc/dnf/dnf.conf"
    sudo sed -i 's/^max_parallel_downloads=.*/max_parallel_downloads=10/' /etc/dnf/dnf.conf

    # Set DNF Default to Yes
    echo "Running: sudo sed -i 's/^#default_yes=default_no/default_yes=default_yes/' /etc/dnf/dnf.conf"
    sudo sed -i 's/^#default_yes=default_no/default_yes=default_yes/' /etc/dnf/dnf.conf

    #Start with Updates
    echo "Running: sudo dnf makecache"
    sudo dnf makecache
    echo "Running: sudo dnf update -y"
    sudo dnf update -y
    # Install Standard Packages
    echo "Running: Standard Package Installs"
    sudo dnf install toilet fortune-mod lolcat vim nano htop google-chrome-stable -y
    sudo dnf remove firefox libreoffice -y
fi

# Add Bashrc Greeting
echo "Adding Greeting"
echo 'echo "Welcome to $(hostname)" | toilet -f term -F border --gay' >> ~/.bashrc
echo 'uptime -p | lolcat' >> ~/.bashrc
echo 'fortune -s | lolcat' >> ~/.bashrc

# Create SSH Keys
echo "Creating SSH Keys"
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< y