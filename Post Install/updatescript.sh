#!/bin/bash
#Run Updates
poweroff=false
reboot=false
backupDirectory="$HOME/Dropbox/Linux Config/$HOSTNAME"

#Update System
function update_system {
        echo -e "\e[32mUpdating System\e[0m"

    if command -v dnf &> /dev/null; then
        echo "dnf is installed, running updates..."
        sudo dnf update -y
    elif command -v apt $> /dev/null; then
        sudo apt update
        sudo apt upgrade -y
    fi

    #Flatpak Updates
    if command -v flatpak &> /dev/null; then
        echo "flatpak is installed, running updates..."
        flatpak upgrade -y
    fi
    #gh updates
    if command -v gh &> /dev/null; then
        echo "gh is installed, running updates..."
        gh extension upgrade --all
    fi
}
function update_githubRepositories {
    #Update bash git repositories
    if [ -d "$HOME/Scripts/bash" ]; then
        echo -e "\e[32mUpdating bash git repository\e[0m"
        git -C "$HOME/Scripts/bash" pull
    fi

    #Update PowerShell git repositories
    if [ -d "$HOME/Scripts/PSScripts" ]; then
        echo -e "\e[32mUpdating PSScripts git repository\e[0m"
        git -C "$HOME/Scripts/PSScripts" pull
    fi
}


function update_rclone {
    #Copy Google Photos to OneDrive -- This is now being done by Deepthought
    echo -e "\e[32mSyncing Google Photos to OneDrive\e[0m"
    echo ""
    rclone copy GooglePhotos:album/ OneDrive:Pictures/ --progress
    
    #Copy Google Photos Shared Albums to OneDrive
    #echo -e "\e[32mSyncing Google Photos Shared Albums to OneDrive\e[0m"
    echo ""
    #rclone copy GooglePhotos:shared-album/ OneDrive:Pictures/ --exclude '*/\{**' --progress

    #Sync Google Photos to Pictures
    echo -e "\e[32mSyncing Google Photos to Pictures\e[0m"
    #echo ""
    rclone copy GooglePhotos:album/ $HOME/Pictures --progress

    #Sync Google Photos Shared Albums to Pictures
    #echo -e "\e[32mSyncing Google Photos Shared Albums to Pictures\e[0m"
    #echo ""
    #rclone copy GooglePhotos:shared-album/ $HOME/Pictures --exclude '*/\{ABZ9**' --progress
}

#Config Backup
function config_backup {
    # Create backup directory if it does not exist
    if [ ! -d "$backupDirectory" ]; then
        echo "Backup directory does not exist. Creating it..."
        mkdir -p "$backupDirectory"
    fi
        mkdir -p "$backupDirectory/bashfiles"
        mkdir -p "$backupDirectory/sshConfig"
        for file in "$HOME"/.bash*; do
            [ -e "$file" ] && cp -R "$file" "$backupDirectory/bashfiles"
        done
        cp -R "$HOME/.ssh" "$backupDirectory/sshConfig"

}

# If no options are specified, run all functions

for option in "$@"; do
    case $option in
        -poweroff)
            echo "System will power off after updates and syncs."
            poweroff=true
            ;;
        -reboot)
            echo "System will reboot after updates and syncs."
            reboot=true
            ;;
        -update)
            echo "Running system update."
            update_system
            ;;
        -rclone)
            echo "Running rclone sync."
            update_rclone
            ;;
        -dropbox)
            echo "Running Dropbox backup."
            dropbox_backup
            ;;
        -config)
            echo "Running config backup."
            config_backup
            ;;
        *)
            echo "Unknown option: $option"
            ;;
    esac
done

if [[ -z "$1" ]]; then
    echo "No options specified. Running all functions."
    update_system
    update_githubRepositories
    update_rclone
    dropbox_backup
    config_backup
fi

if [ "$reboot" = true ]; then
    echo "Rebooting after updates and syncs."
    update_system
    update_githubRepositories
    update_rclone
    dropbox_backup
    config_backup
    sudo reboot
fi


if [ "$poweroff" = true ]; then
    echo "Powering off after updates and syncs."
    update_system
    update_githubRepositories
    update_rclone
    dropbox_backup
    config_backup
    sudo poweroff
fi