#!/bin/bash
# DebianInstall.sh
# This script installs the necessary packages for a Debian system
#Start with Updates
sudo apt update 
sudo apt upgrade -y 

#Install Standard Packages
sudo apt install toilet fortune lolcat vim nano htop cockpit -y

#Add Bashrc Greeting
echo 'echo "Welcome to $(hostname)" | toilet -f term -F border --gay' >> ~/.bashrc
echo 'uptime -p | lolcat' >> ~/.bashrc
echo 'fortune -s | lolcat' >> ~/.bashrc

#Create SSH Keys
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< y