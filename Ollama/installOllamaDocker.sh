#!/bin/bash

# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    
    # Check if running on Raspberry Pi
if [[ $(uname -m) == "arm"* ]]; then
    echo "Running on Raspberry Pi"
    DOCKERURL='https://download.docker.com/linux/debian'
    # Raspberry Pi specific commands or actions
else
    # Check if running on Ubuntu
    if [[ $(lsb_release -si) == "Ubuntu" ]]; then
        echo "Running on Ubuntu"
        DOCKERURL='https://download.docker.com/linux/ubuntu'
    else
        echo "Unknown operating system"
        # Handle other operating systems if needed
    fi
fi

    # Add Docker's official GPG key:
    sudo apt update
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
    sudo apt install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL "$DOCKERURL/gpg" -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $DOCKERURL \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update

    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
else
    echo "Docker is already installed."
fi

#Install Ollama
docker run -d -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main