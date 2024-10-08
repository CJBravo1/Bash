#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31mThis script must be run as root.\e[0m"
   exit 1
fi

# Check if required arguments are provided
if [[ $# -ne 3 ]]; then
    echo -e "\e[31mUsage: $0 <integration_key> <client_secret> <duo_hostname>\e[0m"
    exit 1
fi

# Integration Key, Client Secret, and Duo Hostname
integration_key="$1"
client_secret="$2"
duo_hostname="$3"

# Define file paths
sources_list_path="/etc/apt/sources.list.d/duosecurity.list"
gpg_key_path="/etc/apt/trusted.gpg.d/duo.gpg"
sshd_config_path="/etc/ssh/sshd_config"
common_auth_path="/etc/pam.d/common-auth"

# Define file content for sources.list.d
sources_list_content="deb [arch=amd64] https://pkg.duosecurity.com/Ubuntu jammy main"

# Create the sources.list.d file
echo "$sources_list_content" | sudo tee "$sources_list_path" > /dev/null

# Verify if the file was created successfully
if [ -e "$sources_list_path" ]; then
    echo -e "\e[32mFile created successfully at $sources_list_path\e[0m"
else
    echo -e "\e[31mFailed to create the file at $sources_list_path\e[0m"
    exit 1
fi

# Download the public key and import it
sudo curl -s https://duo.com/DUO-GPG-PUBLIC-KEY.asc | sudo gpg --dearmor -o "$gpg_key_path"

# Verify if the public key was imported successfully
if [ -e "$gpg_key_path" ]; then
    echo -e "\e[32mPublic key imported successfully at $gpg_key_path\e[0m"
else
    echo -e "\e[31mFailed to import the public key at $gpg_key_path\e[0m"
    exit 1
fi

# Update the apt cache
sudo apt update

# Install Duo packages
sudo apt install -y duo-unix

# Backup files
backup_suffix=".bak"

sudo cp "$sources_list_path" "$sources_list_path$backup_suffix"
sudo cp "$sshd_config_path" "$sshd_config_path$backup_suffix"
sudo cp "$common_auth_path" "$common_auth_path$backup_suffix"

# Configure Duo
echo -e "auth    requisite    pam_unix.so nullok_secure\nauth    [success=1 default=ignore]    /lib64/security/pam_duo.so\nauth    requisite    pam_deny.so\nauth    required    pam_permit.so\nauth    optional    pam_cap.so" | sudo tee "$common_auth_path" > /dev/null
echo -e "\e[32mModified $common_auth_path successfully\e[0m"

sudo tee /etc/duo/pam_duo.conf > /dev/null <<EOF
[duo]
; Integration key
ikey = $integration_key

; Secret key
skey = $client_secret

; API hostname
host = $duo_hostname

; Enable Duo Push notifications
pushinfo = yes

; Automatically send a Duo Push when only one factor is required
autopush = yes
EOF
echo -e "\e[32mModified /etc/duo/pam_duo.conf successfully\e[0m"

# Modify sshd_config
sudo sed -i -e 's/^#UsePAM .*/UsePAM yes/' -e 's/^#UseDNS .*/UseDNS no/' -e '/^#UsePAM .*/a ChallengeResponseAuthentication yes' "$sshd_config_path"
echo -e "\e[32mModified $sshd_config_path successfully\e[0m"

# Restart SSH service
sudo systemctl restart sshd

echo -e "\e[32mDuo has been installed and configured successfully.\e[0m"