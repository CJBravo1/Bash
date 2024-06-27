  # Install Docker on Fedora
        if [[ $(lsb_release -si) == "Fedora" ]]; then
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager --add-repo $DOCKERURL
            sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
            sudo systemctl enable docker
            sudo systemctl start docker
        fi
        #Install Ollama Web Interface
        sudo docker run -d --network=host -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://127.0.0.1:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main
    else
        echo "Skipping Docker installation"
    fi
fi