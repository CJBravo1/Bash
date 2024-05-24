#!/bin/bash

# Stop and remove all running containers
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# Remove all Docker images
docker rmi $(docker images -aq)

# Remove Docker volumes
docker volume prune -f

# Remove Docker networks
docker network prune -f

# Remove Docker system-wide configuration
sudo rm -rf /etc/docker

# Purge Docker
sudo apt-get purge docker-ce docker-ce-cli containerd.io

# Remove Docker directories
sudo rm -rf /var/lib/docker

# Remove Docker user group
sudo groupdel docker

# Remove Docker sources from apt
sudo rm /etc/apt/sources.list.d/docker.list

echo "Docker and all containers have been purged successfully, and Docker sources have been removed from apt."