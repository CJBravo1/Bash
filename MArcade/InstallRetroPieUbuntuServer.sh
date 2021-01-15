#!/bin/bash
#Install RetroPie on Ubuntu Server
user=whoami

#Check for Updates
sudo apt update && sudo apt dist-upgrade

#Install Prerequisite Software
sudo apt install git dialog unzip xmlstarlet vim -y

#Install Ubuntu Drivers
sudo apt install ubuntu-drivers-common -y
sudo ubuntu-drivers autoinstall

#Configure Autologin
#Lightdm login file located in /etc/lightdm/lightdm.conf
sudo apt install lightdm openbox -y

#Add lightdm configuration to lightdm.conf
echo "MAKE SURE YOUR USER ACCOUNT IS SET PROPERLY IN THE LIGHTDM.CONF FLIE!!!"
pause
sudo cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak
sudo mv ./lightdm.conf /etc/lightdm/lightdm.conf

#Clone RetroPie Setup Script + Start RetroPie Setup
git clone --depth=1 https://github.com/RetroPie/Retropie-Setup.git
sudo ./RetroPie-Setup/retropie_setup.sh

#Edit Sudoers file
#sudo visudo
#"user" ALL=(ALL)   NOPASSWD:   ALL

#Remove user from sudoers group
#sudo gpasswd -d "user" sudo