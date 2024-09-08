#!/bin/bash
hostname=$(hostname)
if ping -c 1 mintystorage.local &> /dev/null; then
    echo "mintystorage.local is on the network"
    mintystorage=true
else
    echo "mintystorage.local is not on the network"
    mintystorage=false
fi

if [ "$mintystorage" = true ] ; then
    echo -e "\e[32mMounting NAS Share\e[0m"
    sudo mkdir -p /home/cjorenby/NAS
    echo '###NAS Mount###' | sudo tee -a /etc/fstab
    echo "mintystorage:/data/Backup/$hostname /home/cjorenby/NAS nfs defaults 0 0" | sudo tee -a /etc/fstab

    echo -e "\e[32mMounting ISO Share\e[0m"
    sudo mkdir -p /home/cjorenby/ISO
    echo '###ISO Mount###' | sudo tee -a /etc/fstab
    echo "mintystorage:/data/ISO /home/cjorenby/ISO nfs defaults 0 0" | sudo tee -a /etc/fstab
    
    echo -e "\e[32mMounting Movies Share\e[0m"
    sudo mkdir -p /home/cjorenby/Movies
    echo '###Movies Mount###' | sudo tee -a /etc/fstab
    echo "mintystorage:/data/Movies /home/cjorenby/Movies nfs defaults 0 0" | sudo tee -a /etc/fstab

fi
sudo mount -a