#!/bin/bash
# This script is used to install the necessary packages for Ollama

# Function to install Ollama
install_ollama() {
    echo "Installing Ollama"
    curl -fsSL https://ollama.com/install.sh | sh
    sleep 15
}
# Function to install Ollama Modules
install_ollama_modules() {
    echo "Installing Ollama Modules"
    ollama pull llama3
    ollama pull codellama
}
# Function to install Docker Ubuntu
installDockerDebian() {
if [ -f /etc/debian_version ]; then
    sudo apt update
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt remove $pkg; done
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
fi
}
# Function to install Docker Fedora
installdockerFedora() {
    if [ -f /etc/redhat-release ]; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo $DOCKERURL
        sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
}

# Check if running on Raspberry Pi
if [[ $(uname -m) == "arm"* ]]; then
    echo "Running on Raspberry Pi"
    DOCKERURL='https://download.docker.com/linux/debian'
    if [[ $1 == "-InstallDocker" ]]; then
        installDockerDebian
    fi
else
    # Check if running on Ubuntu
    if [[ $(lsb_release -si) == "Ubuntu" ]]; then
        echo "Running on Ubuntu"
        DOCKERURL='https://download.docker.com/linux/ubuntu'
        if [[ $1 == "-InstallDocker" ]]; then
            installDockerDebian
        fi
    fi

    # Check if running on Fedora
    if [[ $(lsb_release -si) == "Fedora" ]]; then
        echo "Running on Fedora"
        DOCKERURL='https://download.docker.com/linux/fedora/docker-ce.repo'
        if [[ $1 == "-InstallDocker" ]]; then
            installdockerFedora
        fi
    else
        echo "Unknown operating system"
        # Handle other operating systems if needed
    fi
fi


# Call the functions if -installOllama option is provided
if [[ $1 == "-installOllama" ]]; then
    install_ollama
    install_ollama_modules
fi

# Check if both options are provided
if [[ $1 == "-installAll" ]]; then
    installDockerDebian
    install_ollama
    install_ollama_modules
fi

if [[ $1 == "-OpenWebUi" ]]; then
    #Install Ollama Web Interface
    # Prompt user for hostname
    read -p "Enter the hostname of the server Ollama is running on: Leave blank for Localhost  " hostname

    # Set hostname to 127.0.0.1 if it is blank
    if [[ -z $hostname ]]; then
        hostname="127.0.0.1"
    fi

    # Install Ollama Web Interface
    sudo docker run -d --network=host -v open-webui:/app/backend/data -e OLLAMA_BASE_URL="http://$hostname:11434" --name open-webui --restart always ghcr.io/open-webui/open-webui:main
else
    echo "Please specify an option"
    echo "-- Options --"
    echo "-installOllama: Install Ollama"
    echo "-InstallDocker: Install Docker"
    echo "-installAll: Install Docker, Ollama, and Ollama Modules"
    echo "-OpenWebUi: Install Ollama Web Interface"
fi
