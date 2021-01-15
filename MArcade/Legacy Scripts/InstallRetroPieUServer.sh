#!/bin/bash
#Install RetroPie on Ubuntu Server
user=whoami

#Check for Updates
sudo apt update && sudo apt dist-upgrade

#Add 'arcade' user to sudoers (password required first time)
#sudo sed -i -e '$a\arcade ALL=(ALL) NOPASSWD:ALL' /etc/sudoers
sudo echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

#Enable Universe repo, update/upgrade and install dependencies
sudo apt-add-repository universe && sudo apt update && sudo apt upgrade -y && sudo apt install xorg openbox pulseaudio alsa-utils menu libglib2.0-bin python-xdg at-spi2-core libglib2.0-bin dbus-x11 git dialog unzip xmlstarlet vim nano --no-install-recommends -y

#Create Openbox autostart script to launch ES using gnome terminal
mkdir ~/.config && mkdir ~/.config/openbox && echo 'gnome-terminal --full-screen --hide-menubar -- emulationstation' >> ~/.config/openbox/autostart

#Create .xsession file
echo 'exec openbox-session' >> ~/.xsession

#Add startx to .bash_profile
echo 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then'  >> ~/.bash_profile && sed -i '$ a\  startx -- -nocursor >/dev/null 2>&1' ~/.bash_profile && sed -i '$ a\fi' ~/.bash_profile

#Configure 'arcade' user to autologin
sudo mkdir /etc/systemd/system/getty@tty1.service.d && sudo sh -c 'echo [Service] >> /etc/systemd/system/getty@tty1.service.d/override.conf' && sudo sed -i '$ a\ExecStart=' /etc/systemd/system/getty@tty1.service.d/override.conf
sudo sed -i '$ a\ExecStart=-/sbin/agetty --skip-login --noissue --autologin $USER %I $TERM' /etc/systemd/system/getty@tty1.service.d/override.conf && sudo sed -i '$ a\Type=idle' /etc/systemd/system/getty@tty1.service.d/override.conf

#Get Retropie Setup script and run it
git clone --depth=1 https://github.com/RetroPie/RetroPie-Setup.git && sudo RetroPie-Setup/retropie_setup.sh
