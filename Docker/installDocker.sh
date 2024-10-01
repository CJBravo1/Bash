#!/bin/bash

# Check if the computer is running Ubuntu
if [ -f /etc/os-release ] && grep -q -E '^(ID|ID_LIKE)="?(debian|ubuntu)"?' /etc/os-release; then
    # Update package list and install prerequisite packages
    sudo apt update
    sudo apt install apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's GPG key to the system
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Add Docker repository to the system
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    # Update package list again
    sudo apt update

    # Install Docker
    sudo apt install docker-ce -y

    # Start Docker service
    sudo systemctl start docker

    # Enable Docker service to start on boot
    sudo systemctl enable docker

    # Verify Docker installation
    #sudo docker run hello-world

    #Install Portainer
    #docker volume create portainer_data

    #Download and install the Portainer Server Container
    #docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

    #echo "URL to Portainer: http://127.0.0.1:9090"

fi
# Check if the computer is running Fedora
if [ -f /etc/os-release ] && grep -q -E '^(ID|ID_LIKE)="?(fedora)"?' /etc/os-release; then
    # Install prerequisite packages
    sudo dnf install -y dnf-plugins-core

    # Add Docker repository to the system
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

    # Update package list
    sudo dnf update -y

    # Install Docker
    sudo dnf install -y docker-ce docker-ce-cli containerd.io

    # Start Docker service
    sudo systemctl start docker

    # Enable Docker service to start on boot
    sudo systemctl enable docker

    #Install Portainer
    docker volume create portainer_data

    #Download and install the Portainer Server Container
    docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

    echo "URL to Portainer: http://127.0.0.1:9090"
fi

