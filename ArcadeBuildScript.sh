#!/bin/bash
#Start Auto Update
sudo apt update
sudo apt upgrade -y

#Add Arcade user to sudoers
sudo sed -i -e '$a\arcade ALL=(ALL) NOPASSWD:ALL' /etc/sudoers

#Enable Universe Repo.
sudo apt-add-repository universe 
sudo apt-get update
sudo apt-get upgrade -y 
sudo apt install xorg openbox pulseaudio alsa-utils menu libglib2.0-bin python-xdg at-spi2-core libglib2.0-bin dbus-x11 git dialog unzip xmlstarlet --no-install-recommends -y
sudo apt install x11vnc -y

#Create Openbox autostart script to launch EmulationStation using gnome terminal
mkdir ~/.config
mkdir ~/.config/openbox
echo 'gnome-terminal --full-screen --hide-menubar -- emulationstation' >> ~/.config/openbox/autostart

#Create .xsession file
echo 'exec openbox-session' >> ~/.xsession

#Add startx to .bash_profile
echo 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then'  >> ~/.bash_profile 
sed -i '$ a\  startx -- -nocursor >/dev/null 2>&1' ~/.bash_profile 
sed -i '$ a\fi' ~/.bash_profile

#Configure Arcade user to auto login
sudo mkdir /etc/systemd/system/getty@tty1.service.d 
sudo sh -c 'echo [Service] >> /etc/systemd/system/getty@tty1.service.d/override.conf' 
sudo sed -i '$ a\ExecStart=' /etc/systemd/system/getty@tty1.service.d/override.conf 
sudo sed -i '$ a\ExecStart=-/sbin/agetty --skip-login --noissue --autologin arcade %I $TERM' /etc/systemd/system/getty@tty1.service.d/override.conf 
sudo sed -i '$ a\Type=idle' /etc/systemd/system/getty@tty1.service.d/override.conf

#Create Startup Script
touch StartupScript.sh
echo '#!/bin/bash' > StartupScript.sh 
#Set Screen resolution
echo 'xrandr --newmode "640x480-15khz" 13.218975 640 672 736 840 480 484 490 525 -HSync -VSync interlace' >> StartupScript.sh 
echo 'xrandr --addmode DVI-I-1 "640x480-15khz"' >> StartupScript.sh
echo 'xrandr --output DVI-I-1 --mode "640x480-15khz"' >> StartupScript.sh
#gnome-terminal --full-screen --hide-menubar -- emulationstation
echo 'gnome-terminal --full-screen --hide-menubar -- emulationstation' >> StartupScript.sh

#Add Startup Script command to Openbox Startup Script
echo '/home/arcade/StartupScript.sh' >> .config/openbox/autostart


#Start RetroPie Script
git clone --depth=1 https://github.com/RetroPie/RetroPie-Setup.git 
#sudo RetroPie-Setup/retropie_setup.sh

#Enable Startup Script
sudo chmod -v +x StartupScript.sh

echo "It is recomended to reboot before running RetroPie-Setup/retropie_setup.sh"
echo "Run the Retropie Setup Script on the local machine"