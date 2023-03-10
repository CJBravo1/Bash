#!/bin/bash

#Check for / Install Updates
sudo apt update
sudo apt upgrade -y
flatpak upgrade -y

#Repositories
sudo add-apt-repository multiverse
sudo apt update

#Initial Apt Install
#Array of package names
packages=(
    "apt-transport-https"
    "code"
    "fortune"
    "lolcat"
    "neofetch"
    "nfs-common"
    "rclone"
    "software-properties-common"
    "steam"
    "toilet"
    "gir1.2-gda-5.0"
    "gir1.2-gsound-1.0"
    )
#Install Software | Refresh font cache
sudo apt install -y $packages

#Install Microsoft Fonts
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
sudo apt install ttf-mscorefonts-installer
sudo fc-cache -f -v

#Flatpak Installs
# List of Flatpak applications to install
flatpaks=(
    "com.spotify.Client"
    "com.github.tchx84.Flatseal"
    )
# Install flatpak applications
flatpak install -y ${flatpaks[*]}

#Install Gnome Extensions #####WORK IN PROGRESS!!!!####
#List of GNOME extensions to install
extensions=(
    "add-username-toppanel@brendaw.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "cosmic-dock@system76.com"
    "cosmic-workspaces@system76.com"
    "clipboard-indicator@tudmotu.com"
    "ding@rastersoft.com"
    "pano@elhan.io"
    "pop-cosmic@system76.com"
    "pop-shell@system76.com"
    "popx11gestures@system76.com"
    "system76-power@system76.com"
    "ubuntu-appindicators@ubuntu.com"
    "spotify-controller@koolskateguy89"
)

#Install GNOME extensions from the list
for ext in "${extensions[@]}"
do
  gnome-extensions install "$ext"
done

#Install Google Chrome
wget -P ~/Downloads https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ~/Downloads/google-chrome-stable_current_amd64.deb
rm -v ~/Downloads/google-chrome-stable_current_amd64.deb

#Install Powershell
#Download the Microsoft repository GPG keys
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
#Register the Microsoft repository GPG keys
sudo dpkg -i packages-microsoft-prod.deb
#Update the list of packages after we added packages.microsoft.com
sudo apt update
#Install PowerShell
sudo apt install -y powershell

cd ~/Downloads && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -
~/Downloads/.dropbox-dist/dropboxd


#Generate ssh key
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""