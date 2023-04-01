#!/bin/bash

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
