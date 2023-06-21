#!/bin/bash

# Define file paths
sources_list_path="/etc/apt/sources.list.d/duosecurity.list"
gpg_key_path="/etc/apt/trusted.gpg.d/duo.gpg"

# Define file content for sources.list.d
sources_list_content="deb [arch=amd64] https://pkg.duosecurity.com/Ubuntu jammy main"

# Define the URL for the public key
public_key_url="https://duo.com/DUO-GPG-PUBLIC-KEY.asc"

# Create the sources.list.d file
echo "$sources_list_content" | sudo tee "$sources_list_path" > /dev/null

# Verify if the file was created successfully
if [ -e "$sources_list_path" ]; then
    echo "File created successfully at $sources_list_path"
else
    echo "Failed to create the file at $sources_list_path"
    exit 1
fi

# Download the public key and import it
sudo curl -s "$public_key_url" | sudo gpg --dearmor -o "$gpg_key_path"

# Verify if the public key was imported successfully
if [ -e "$gpg_key_path" ]; then
    echo "Public key imported successfully at $gpg_key_path"
else
    echo "Failed to import the public key at $gpg_key_path"
    exit 1
fi

# Update the apt cache
sudo apt update
sudo apt install duo-unix
