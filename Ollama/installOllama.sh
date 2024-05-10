#!/bin/bash
# This script is used to install the necessary packages for Ollama

#Update Apt
sudo apt update

#Install Ollama
echo "Installing Ollama"
curl -fsSL https://ollama.com/install.sh | sh

#Install Docker
# Add Docker's official GPG key:

sudo apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings 
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

#Install Docker
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

#Install Ollama Web Interface
docker run -d --network=host -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://127.0.0.1:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main