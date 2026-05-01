#!/bin/bash
# Run this after OS install. This script will install some standard packages and set up some basic configurations.

# Set variables
ACTUAL_USER=$SUDO_USER
ACTUAL_HOME=$(eval echo ~$SUDO_USER)
LOG_FILE="/var/log/PostInstall.log"

# Check if Flatpak is installed
FLATPAK_INSTALLED=false
if command -v flatpak >/dev/null 2>&1; then
    FLATPAK_INSTALLED=true
fi

####Functions####
###Script Functions###

echo_green () {
    echo "$1"
}

get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

check_WINDOW_MANAGER() {
    if [ -n "$XDG_CURRENT_DESKTOP" ] || [ -n "$DESKTOP_SESSION" ]; then
        log_message "Window manager is installed"
        WINDOW_MANAGER=true
        return 0
    else
        log_message "No window manager detected"
        WINDOW_MANAGER=false
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

five_second_countdown() {
    echo "Rebooting in 5 seconds..."
    for i in {5..1}; do
        echo "$i"
        sleep 1
    done
}

addGreetings() {
#Copy bash_aliases and bash_functions
echo_green " Adding Bash functions and aliases"
cat ~/Scripts/bash/Post\ Install/.bashrc >> ~/.bashrc 
cp -v ~/Scripts/bash/Post\ Install/.bash_aliases ~/
cp -v ~/Scripts/bash/Post\ Install/.bash_functions ~/
cp -v ~/Scripts/bash/Post\ Install/updatescript.sh ~/
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
        #app.drey.Damask
        #com.dropbox.Client
        com.github.tchx84.Flatseal
        com.mattjakeman.ExtensionManager
        com.spotify.Client
        com.transmissionbt.Transmission
        #org.raspberrypi.rpi-imager
        io.github.davidoc26.wallpaper_selector
        io.github.realmazharhussain.GdmSettings
        io.github.sigmasd.stimulator
        io.missioncenter.MissionCenter
        #org.gnome.Firmware
        org.gnome.World.PikaBackup
        org.remmina.Remmina
    )

    # Install all flatpaks at once
    echo_green "Installing ${flatpaks[@]}"  # Echo in green color
    # This command installs the Flatpaks specified in the 'flatpaks' array.
    flatpak install -y ${flatpaks[@]}
}

installGoogleChromeDeb() {
    log_message "Installing Google Chrome"
        if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
            # Install Google Chrome
            echo_green "Installing Google Chrome"  # Echo in green color
            wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
            sudo dpkg -i google-chrome-stable_current_amd64.deb
            sudo apt install -f -y
            rm google-chrome-stable_current_amd64.deb
        else
            echo "Google Chrome is already installed"
        fi
}

installGoogleChromeRpm() {
    echo_green "Installing Google Chrome"  # Echo in green color
    sudo dnf install google-chrome-stable -y
}

installGoogleChromeFlatpak() {
    echo_green "Installing Google Chrome"  # Echo in green color
    flatpak install flathub com.google.Chrome -y
    flatpak override --user --filesystem=~/.local/share/applications --filesystem=~/.local/share/icons com.google.Chrome

}


installVSCodeRPM()
{
        #Install VSCode
    echo_green "Installing Visual Studio Code"  # Echo in green color
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    dnf check-update
    sudo dnf install code -y
}

installVSCodeDeb(){
    echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
    sudo apt -y install wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    sudo apt install apt-transport-https
    sudo apt update
    sudo apt install -y code # or code-insiders


}

installPowershell()
{
    # Install PowerShell
    log_message "Installing PowerShell"
    if ! command -v pwsh >/dev/null 2>&1; then
        # Install PowerShell
        echo_green "Installing PowerShell"  # Echo in green color
        if [ -f /etc/debian_version ]; then
            # Install PowerShell for Debian-based systems
            # Update the list of packages
            sudo apt update

            # Install pre-requisite packages.
            sudo apt install -y wget

            # Get the version of Debian
            source /etc/os-release

            # Download the Microsoft repository GPG keys
            wget -q https://packages.microsoft.com/config/debian/$VERSION_ID/packages-microsoft-prod.deb

            # Register the Microsoft repository GPG keys
            sudo dpkg -i packages-microsoft-prod.deb

            # Delete the Microsoft repository GPG keys file
            rm packages-microsoft-prod.deb

            # Update the list of packages after we added packages.microsoft.com
            sudo apt update

            ###################################
            # Install PowerShell
            sudo apt install -y powershell

        elif [ -f /etc/redhat-release ]; then
            # Install PowerShell for Fedora
            # Get version of RHEL
            source /etc/os-release
            if [ ${VERSION_ID%.*} -lt 8 ]
            then majorver=7
            elif [ ${VERSION_ID%.*} -lt 9 ]
            then majorver=8
            else majorver=9
            fi

            # Download the Microsoft RedHat repository package
            curl -sSL -O https://packages.microsoft.com/config/rhel/$majorver/packages-microsoft-prod.rpm

            # Register the Microsoft RedHat repository
            sudo rpm -i packages-microsoft-prod.rpm

            # Delete the downloaded package after installing
            rm packages-microsoft-prod.rpm

            # Update package index files
            sudo dnf update
            # Install PowerShell
            sudo dnf install powershell -y
        fi
    else
        echo "PowerShell is already installed"
    fi
}


customize_gnome() {
    # Customize GNOME settings
    log_message "Customizing GNOME settings"
    gsettings set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
    
    # Install Extensions for GNOME if RedHat-based
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y\
        gnome-tweaks\
        gnome-shell-extension-dash-to-dock
    elif command -v apt >/dev/null 2>&1; then
        sudo apt install -y\
         gnome-tweaks\
         gnome-shell-extension-dash-to-dock
    fi
    gnome-extensions enable
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
    sudo apt install -y\
    borgbackup\
    curl\
    fortune\
    gh\
    gnome-firmware\
    htop\
    lolcat\
    nano\
    nfs-common\
    toilet\
    vim

    # Check if a window manager is installed
    if check_WINDOW_MANAGER; then
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
    else
        echo "No window manager detected, skipping Flatpak installation"
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

###Redhat###
installFedora() {

    # Set DNF Parallel Downloads
    sudo cp "/etc/dnf/dnf.conf" "/etc/dnf/dnf.conf.bak"
    echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
    echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
    sudo dnf -y install dnf-plugins-core
    
    if rpm -q firefox >/dev/null 2>&1; then
        sudo dnf remove firefox -y
    fi
    if rpm -q libreoffice >/dev/null 2>&1; then
        sudo dnf remove libreoffice-* -y
    fi

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
    sudo dnf install -y \
        borgbackup \
        fastfetch \
        fortune-mod \
        gh \
        gnome-firmware \
        gparted \
        htop \
        lolcat \
        mscore-fonts-all \
        nano \
        pv \
        rclone \
        toilet \
        tmux \
        vim


    # Check for firmware updates
    log_message "Checking for firmware updates..."
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates
    sudo fwupdmgr update -y

    # Check if the OS is running as a virtual machine
    if grep -qE "(vmware|virtualbox|qemu|kvm|xen|hyper-v)" /proc/cpuinfo || systemd-detect-virt -q; then
        sudo plymouth-set-default-theme tribar -R
    else
        log_message "Not running inside a virtual machine."
    fi
}

#Auto Enroll LUKS key into TPM
enroll_luks_tpm() {

  ## Inspect Kernel Cmdline for rd.luks.uuid
  RD_LUKS_UUID="$(xargs -n1 -a /proc/cmdline | grep rd.luks.uuid | cut -d = -f 2)"

  # Check to make sure cmdline rd.luks.uuid exists
  if [[ -z ${RD_LUKS_UUID:-} ]]; then
    printf "LUKS device not defined on Kernel Commandline.\n"
    printf "This is not supported by this script.\n"
    printf "Exiting...\n"
    return 1
  fi

  # Check to make sure that the specified cmdline uuid exists.
  if ! grep -q "${RD_LUKS_UUID}" <<< "$(lsblk)" ; then
    printf "LUKS device not listed in block devices.\n"
    printf "Exiting...\n"
    return 1
  fi

  # Cut off the luks-
  LUKS_PREFIX="luks-"
  if grep -q ^${LUKS_PREFIX} <<< "${RD_LUKS_UUID}"; then
    DISK_UUID=${RD_LUKS_UUID#"$LUKS_PREFIX"}
  else
    echo -e "\e[31mLUKS UUID format mismatch."
    echo -e "\e[31mExiting..."
    return 1
  fi

  SET_PIN_ARG=""
  # Always proceed without setting a PIN

  # Specify Crypt Disk by-uuid
  CRYPT_DISK="/dev/disk/by-uuid/$DISK_UUID"

  # Check to make sure crypt disk exists
  if [[ ! -L "$CRYPT_DISK" ]]; then
    printf "LUKS device not listed in block devices.\n"
    printf "Exiting...\n"
    return 1
  fi

    if sudo cryptsetup luksDump "$CRYPT_DISK" | grep systemd-tpm2 > /dev/null; then
    KEYSLOT=$(cryptsetup luksDump "$CRYPT_DISK" | sed -n '/systemd-tpm2$/,/Keyslot:/p' | grep Keyslot|awk '{print $2}')
    echo "TPM2 already present in LUKS keyslot $KEYSLOT of $CRYPT_DISK. Automatically wiping it and re-enrolling."
    sudo systemd-cryptenroll --wipe-slot=tpm2 "$CRYPT_DISK"
fi

  ## Run crypt enroll
  echo_green "Enrolling TPM2 unlock requires your existing LUKS2 unlock password"
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+1+2 "$CRYPT_DISK"
# Modify /etc/crypttab to include tpm2-device=auto for the relevant LUKS device


if [ -n "$LUKS_NAME" ]; then
    sudo sed -i "/$LUKS_NAME\|$DISK_UUID/ s/$/ ,tpm2-device=auto/" "$CRYPTTAB_FILE"
    log_message "Added tpm2-device=auto to $CRYPTTAB_FILE for $LUKS_NAME"
else
    log_message "Could not find LUKS device name for UUID $DISK_UUID in lsblk output."
fi
# Regenerate initramfs and update GRUB to accept the new enrollment
if command -v dracut >/dev/null 2>&1; then
    sudo dracut --force --add tpm2-tss
    log_message "Regenerated initramfs with dracut."
fi

if command -v update-grub >/dev/null 2>&1; then
    sudo update-grub
    log_message "Updated GRUB bootloader."
elif command -v grub2-mkconfig >/dev/null 2>&1; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    log_message "Updated GRUB2 bootloader."
fi

  if lsinitrd 2>&1 | grep -q tpm2-tss > /dev/null; then
    ## add tpm2-tss to initramfs
    if rpm-ostree initramfs | grep tpm2 > /dev/null; then
      echo "TPM2 already present in rpm-ostree initramfs config."
      sudo rpm-ostree initramfs
      echo -e "\e[33mRe-running initramfs to pickup changes above."
    fi
    sudo rpm-ostree initramfs --enable --arg=--force-add --arg=tpm2-tss
  else
    ## initramfs already containts tpm2-tss
    echo -e "\e[33mTPM2 already present in initramfs."
  fi

  ## Now reboot
  echo
  echo_green "TPM2 LUKS auto-unlock configured."
}


installSilverblue() {
    # Set rpm-ostree parallel downloads
    sudo cp "/etc/rpm-ostree.conf" "/etc/rpm-ostree.conf.bak"
    echo "max_parallel_downloads=10" | sudo tee -a /etc/rpm-ostree.conf > /dev/null

    # Enable RPM Fusion repositories for Silverblue
    rpm-ostree install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    rpm-ostree install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    # Update the system
    echo "Running: rpm-ostree upgrade"
    sudo rpm-ostree upgrade

    # Install Standard Packages
    echo "Running: Standard Package Installs"
    rpm-ostree install toilet borgbackup fortune-mod lolcat vim nano htop gh pv fastfetch gnome-firmware rclone mscore-fonts-all

    # Remove unwanted packages
    echo "Removing unwanted packages"
    if rpm -q firefox >/dev/null 2>&1; then
        rpm-ostree override remove firefox
    else
        echo "Firefox is not installed"
    fi

    if rpm -q libreoffice >/dev/null 2>&1; then
        rpm-ostree override remove libreoffice
    else
        echo "LibreOffice is not installed"
    fi

    # Check for firmware updates
    log_message "Checking for firmware updates..."
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates
    sudo fwupdmgr update -y

    # Check if the OS is running as a virtual machine
    if grep -qE "(vmware|virtualbox|qemu|kvm|xen|hyper-v)" /proc/cpuinfo || systemd-detect-virt -q; then
        sudo plymouth-set-default-theme tribar -R
    else
        log_message "Not running inside a virtual machine."
    fi

    # Apply pending changes and reboot
    echo "Applying changes and rebooting..."
    sudo rpm-ostree finalize 
    sudo rpm-ostree cleanup -m
}


#####START OF SCRIPT#####
check_WINDOW_MANAGER

# Clone the Bash Scripts repository
if ! command -v git >/dev/null 2>&1; then
    echo "git is not installed. Please install git and rerun the script."
    exit 1
fi

if [ -d $ACTUAL_HOME/Scripts/bash ]; then
    echo "Bash directory already exists"
else
    echo "Cloning Bash Scripts repository"
    mkdir -p ~/Scripts
    git clone https://github.com/cjbravo1/bash ~/Scripts/bash
    POST_INSTALL_DIR=$ACTUAL_HOME/Scripts/bash/Post\ Install
fi

# Check if the OS is Debian-based
if [ -f /etc/debian_version ]; then
    installDebian

    if $WINDOW_MANAGER; then
        if $FLATPAK_INSTALLED; then
            #Install Google Chrome
            installGoogleChromeFlatpak
        else
            installGoogleChromeDeb
        fi
    fi
fi

# Check if the OS is Fedora
if [ -f /etc/redhat-release ]; then
    installFedora

    if $WINDOW_MANAGER; then
        if $FLATPAK_INSTALLED; then
            #Install Google Chrome
            installGoogleChromeFlatpak
        else
            installGoogleChromeRpm
        fi
    fi
fi
 
# Check if the OS is Silverblue
if [ -f /etc/os-release ] && grep -qE "Silverblue|Kinoite" /etc/os-release; then
    if grep -q "Fedora" /etc/os-release; then
        installSilverblue
        if $WINDOW_MANAGER; then
            #Install Google Chrome
            installGoogleChromeFlatpak
        fi
    fi
fi

# Install Flatpacks
if $WINDOW_MANAGER; then
    # Install Flatpacks
    echo_green "Installing Flatpacks"  # Echo in green color
    installGoogleChromeFlatpak
    installFlatpacks
    # Customize GNOME if it's the window manager
    if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
        customize_gnome
    fi
fi

### Optional Configurations ###

#Set Hostname
read -p "Do you want to set the hostname? (y/n): " set_hostname
if [ "$set_hostname" = "y" ]; then
    read -p "Enter the new hostname: " new_hostname
    sudo hostnamectl set-hostname "$new_hostname"
    log_message "Hostname set to $new_hostname"
fi

# Enroll LUKS key into TPM
read -p "Do you want to enroll LUKS key into TPM? (y/n): " enroll_tpm
if [ "$enroll_tpm" = "y" ]; then
    if command -v systemd-cryptenroll >/dev/null 2>&1; then
        enroll_luks_tpm
    else
        echo "systemd-cryptenroll is not installed. Please install it and rerun the script."
    fi
fi

### Optional Installs ###

#Install Visual Studio Code
read -p "Do you want to install Visual Studio Code? (y/n): " install_vscode
if [ "$install_vscode" = "y" ]; then
    if [ -f /etc/debian_version ]; then
        installVSCodeDeb
    elif [ -f /etc/redhat-release ]; then
        installVSCodeRPM
    fi
fi

# Install Docker
read -p "Do you want to install Docker? (y/n): " install_docker
if [ "$install_docker" = "y" ]; then
    installDocker
fi

# Check if the user wants to install GitHub Copilot
read -p "Do you want to install GitHub Copilot? (y/n): " install_copilot
if [ "$install_copilot" = "y" ]; then
    installGhCopilot
fi

# Install Tailscale
read -p "Do you want to install Tailscale? (y/n): " install_tailscale
if [ "$install_tailscale" = "y" ]; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi

#Install Steam
read -p "Do you want to install Steam? (y/n): " install_steam
if [ "$install_steam" = "y" ]; then
    if [ -f /etc/debian_version ]; then
        sudo apt install steam -y
    elif [ -f /etc/redhat-release ]; then
        sudo dnf install steam -y
    fi
fi

#Install Powershell
read -p "Do you want to install PowerShell? (y/n): " install_powershell
if [ "$install_powershell" = "y" ]; then
    installPowershell
fi


# Create SSH Keys
echo "Creating SSH Keys"
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< y

# Add Bash Greetings
addGreetings

#Restart the shell
source ~/.bashrc

# End of Script
echo -e "\e[32EEnd of Script"  # Echo in green color