#!/bin/bash
#Create Portainer Volume
docker volume create portainer_data

#Download and install the Portainer Server Container
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest