#!/bin/bash
# Run this after OS install. This script will install some standard packages and set up some basic configurations.



# Set variables
ACTUAL_USER=$SUDO_USER
ACTUAL_HOME=$(eval echo ~$SUDO_USER)
LOG_FILE="/var/log/PostInstall.log"

####Functions####
###Script Functions###
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

check_window_manager() {
    if [ -n "$XDG_CURRENT_DESKTOP" ] || [ -n "$DESKTOP_SESSION" ]; then
        log_message "Window manager is installed"
        return 0
    else
        log_message "No window manager detected"
        return 1
    fi
}

handle_error() {
    local exit_code=$?
    local message="$1"
    if [ $exit_code -ne 0 ]; then
        log_message "ERROR: $message"
        exit $exit_code
    fi
}

log_message() {
    local message="$1"
    echo "$(get_timestamp) - $message" | tee -a "$LOG_FILE"
}


backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$file.bak"
        handle_error "Failed to backup $file"
        log_message "Backed up $file"
    fi
}

###Install Functions###
cloneBashScripts() {
    log_message "Cloning Bash Scripts repository"
    # Clone the Bash Scripts repository
    if [ -d $ACTUAL_HOME/Scripts/bash ]; then
        echo "Bash directory already exists"
    else
        echo "Cloning Bash Scripts repository"
        mkdir -p ~/Scripts
        git clone https://github.com/cjbravo1/bash ~/Scripts/Bash
    fi
}

installDocker(){
    curl -sSL https://get.docker.com | sh
}

installGhCopilot() {
    log_message "Installing GitHub Copilot"
    if command -v gh >/dev/null 2>&1; then
        echo "gh is installed"
        gh auth login
        gh extension install github/gh-copilot
        #gh copilot alias bash >> ~/.bashrc
    else
        echo "gh is not installed"
    fi
}

installFlatpacks() {
    log_message "Installing Flatpaks"
    flatpaks=(
        app.drey.Damask
        com.dropbox.Client
        com.mattjakeman.ExtensionManager
        com.spotify.Client
        com.transmissionbt.Transmission
        #org.raspberrypi.rpi-imager
        io.github.realmazharhussain.GdmSettings
        io.github.sigmasd.stimulator
        io.missioncenter.MissionCenter
        #org.gnome.Firmware
        org.gnome.World.PikaBackup
        org.remmina.Remmina
        

    )
    # Install all flatpaks at once
    echo -e "\e[32mInstalling ${flatpaks[@]}\e[0m"  # Echo in green color
    # This command installs the Flatpaks specified in the 'flatpaks' array.
    flatpak install -y ${flatpaks[@]}
}

installGoogleChrome() {
    log_message "Installing Google Chrome"
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


####OS Specific Functions####
installDebian() {    
    log_message "Performing system upgrade... This may take a while..."
    # Start with Updates
    echo "Running: sudo apt update"
    sudo apt update
    echo "Running: sudo apt upgrade -y"
    sudo apt upgrade -y
    # Install Standard Packages
    echo "Running: sudo apt install toilet fortune lolcat vim nano htop -y"
    sudo apt install toilet fortune lolcat vim nano htop gh nfs-common gnome-firmware  -y

    # Set DNS Settings
    if [[ $(hostname -I) =~ 192\.168\.12\.[0-9]+ ]] && [[ $(hostname -I) != "192.168.12.234" ]]; then
        echo "Setting DNS to 192.168.12.234"
        echo "nameserver 192.168.12.234" | sudo tee /etc/resolv.conf > /dev/null
    fi

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
    
}

installFedora() {
    log_message "Performing system upgrade... This may take a while..."
    
    # Set DNF Parallel Downloads
    sudo cp "/etc/dnf/dnf.conf" "/etc/dnf/dnf.conf.bak"
    echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
    echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
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
    sudo dnf install toilet fortune-mod lolcat vim nano htop gh pv fastfetch gnome-firmware -y
    sudo dnf remove firefox libreoffice -y

    # Check for firmware updates
    log_message "Checking for firmware updates..."
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates
    sudo fwupdmgr update -y
}

###Post Install Functions###
addBashGreeting()
    {
        if ! grep -q "Welcome to $(hostname)" ~/.bashrc; then
        echo 'echo "Welcome to $(hostname)" | toilet -f term -F border --gay' >> ~/.bashrc
        fi

        if ! grep -q "uptime -p" ~/.bashrc; then
            echo 'uptime -p | lolcat' >> ~/.bashrc
        fi

        if ! grep -q "fortune -s" ~/.bashrc; then
            echo 'fortune -s | lolcat' >> ~/.bashrc
        fi
    }

#####START OF SCRIPT#####
cloneBashScripts

# Check if the OS is Debian-based
if [ -f /etc/debian_version ]; then
    installDebian
# Check if the OS is Fedora
elif [ -f /etc/redhat-release ]; then
    installFedora
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    #Install Google Chrome
    echo -e "\e[32mInstalling Google Chrome\e[0m"  # Echo in green color
    sudo dnf install google-chrome-stable -y
    fi
fi

# Install Docker
read -p "Do you want to install Docker? (y/n): " install_docker
if [ "$install_docker" = "y" ]; then
    installDocker
fi

#Add Bash Greeting
addBashGreeting

# Install Flatpacks and Google Chrome
if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    # Install Flatpacks
    echo -e "\e[32mInstalling Flatpacks\e[0m"  # Echo in green color
    installFlatpacks

    # Install Google Chrome
    echo -e "\e[32mInstalling Google Chrome\e[0m"  # Echo in green color
    installGoogleChrome
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
echo -e "\e[32EEnd of Script\e[0m"  # Echo in green color

