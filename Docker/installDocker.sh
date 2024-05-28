#!/bin/bash

# Check if the computer is running Ubuntu
if [[ $(lsb_release -is) == "Ubuntu" ]]; then
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
    sudo apt install docker-ce

    # Verify Docker installation
    sudo docker run hello-world
fi
# Check if the computer is running Fedora
if [[ $(cat /etc/os-release | grep -oP '(?<=^ID=).+' | tr -d '"') == "fedora" ]]; then
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

    # Verify Docker installation
    #sudo docker run hello-world
fi

