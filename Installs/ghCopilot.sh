#!/bin/bash

# Check if the OS is Red Hat based
if [ -f /etc/redhat-release ]; then
    echo "Red Hat based OS detected."
    # Add your Red Hat specific commands here
    sudo dnf install gh -y
fi
fi

# Check if the OS is Debian based
if [ -f /etc/debian_version ]; then
    echo "Debian based OS detected."
    # Add your Debian specific commands here
fi

#Sign into GitHub and Download gh copilot
echo "Signing into GitHub"
gh auth login
echo "Installing gh copilot"
gh extension install github/gh-copilot
gh copilot version
echo "Adding gh copilot alias to bashrc"
gh copilot alias bash >> ~/.bashrc