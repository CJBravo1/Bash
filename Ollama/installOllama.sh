#!/bin/bash
# This script is used to install the necessary packages for Ollama

#Update Apt
sudo apt update
sudo apt upgrade -y

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

#Install Ollama
echo "Installing Ollama"
curl -fsSL https://ollama.com/install.sh | sh
sleep 15

#Install Ollama Modules
echo "Installing Ollama Modules"
ollama pull llama3
ollama pull codellama

#Install Docker
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

#Install Ollama Web Interface
sudo docker run -d --network=host -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://127.0.0.1:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main