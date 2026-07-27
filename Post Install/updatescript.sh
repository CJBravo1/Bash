#!/bin/bash
#Run Updates
poweroff=false
reboot=false
backupDirectory="$HOME/.Backup"

#Update System
function update_system {
        echo -e "\e[32mUpdating System\e[0m"

    if command -v dnf &> /dev/null; then
        echo "dnf is installed, running updates..."
        sudo dnf update -y
        sudo dnf autoremove -y
    elif command -v apt &> /dev/null; then
        sudo apt update
        sudo apt upgrade -y
        sudo apt autoremove -y
    fi

    #Flatpak Updates
    if command -v flatpak &> /dev/null; then
        echo "flatpak is installed, running updates..."
        flatpak upgrade -y
    fi
}

function wait_for_kernel_update_completion {
    # Ensure package manager/kernel install work is complete before reboot/poweroff
    while pgrep -x dnf >/dev/null || \
          pgrep -x apt >/dev/null || \
          pgrep -x apt-get >/dev/null || \
          pgrep -x dpkg >/dev/null || \
          pgrep -x rpm >/dev/null || \
          pgrep -x dracut >/dev/null || \
          pgrep -x mkinitcpio >/dev/null || \
          pgrep -x update-initramfs >/dev/null || \
          pgrep -f "grub2-mkconfig|update-grub|grub-mkconfig" >/dev/null; do
        echo "Kernel/package update still in progress. Waiting before reboot/poweroff..."
        sleep 5
    done
}

function update_githubRepositories {
    #Update bash git repositories
    if [ -d "$HOME/Scripts/bash" ]; then
        echo -e "\e[32mUpdating bash git repository\e[0m"
        git -C "$HOME/Scripts/bash" pull

        #Copy updatescript.sh to home directory if it has changed
        repo_update_script="$HOME/Scripts/bash/Post Install/updatescript.sh"
        home_update_script="$HOME/updatescript.sh"
        if [ -f "$repo_update_script" ] && ! cmp -s "$repo_update_script" "$home_update_script"; then
            echo -e "\e[32mupdatescript.sh has changed, copying to home directory\e[0m"
            cp "$repo_update_script" "$home_update_script"
            chmod +x "$home_update_script"
        fi
    fi

    #Update PowerShell git repositories
    if [ -d "$HOME/Scripts/PSScripts" ]; then
        echo -e "\e[32mUpdating PSScripts git repository\e[0m"
        git -C "$HOME/Scripts/PSScripts" pull
    fi


}

function update_functions {
    # Add the contents of .bash_functions from the URL to .bash_functions if not already there
    bash_functions_file="$HOME/Scripts/bash/Post Install/.bash_functions"
    declare -A files=(
        ["$HOME/Scripts/bash/Post Install/.bash_functions"]="https://raw.githubusercontent.com/CJBravo1/Bash/refs/heads/master/Post%20Install/.bash_functions"
        ["$HOME/Scripts/bash/Post Install/.bash_aliases"]="https://raw.githubusercontent.com/CJBravo1/Bash/refs/heads/master/Post%20Install/.bash_aliases"
    )

    for file in "${!files[@]}"; do
        url="${files[$file]}"
        if ! grep -qF "$(curl -s "$url")" "$file"; then
            echo -e "\e[32mAdding contents from $url to $file\e[0m"
            curl -s "$url" >> "$file"
        else
            echo -e "\e[32mContents from $url already present in $file\e[0m"
        fi
    done
}

function update_remoteHosts {
    if [ "$(hostname)" != "wonder" ]; then
        return
    fi

    local hosts=(airwave soundwave)
    for host in "${hosts[@]}"; do
        echo -e "\e[32mRunning updatescript.sh on $host\e[0m"
        ssh "$host" '~/updatescript.sh'
    done
}

update_pihole() {
    echo -e "\e[32mUpdating Pi-hole\e[0m"
    pihole_container=$(docker ps --filter "ancestor=pihole/pihole" --format "{{.Names}}" 2>/dev/null | head -n1)
    if [ -n "$pihole_container" ]; then
        echo "Pi-hole container '$pihole_container' is running, updating gravity..."
        docker exec "$pihole_container" pihole -g
    elif command -v pihole &> /dev/null || type pihole &> /dev/null; then
        echo "Pi-hole is installed, running update..."
        pihole -g
    else
        echo "Pi-hole is not installed or not running, skipping update."
    fi
}

# If no options are specified, run all functions

function run_all_tasks {
    update_system
    if [ -n "$(docker ps --filter "ancestor=pihole/pihole" --format "{{.Names}}" 2>/dev/null)" ] || \
       command -v pihole &> /dev/null || type pihole &> /dev/null; then
        update_pihole
    fi
    update_githubRepositories
    update_remoteHosts
}

for option in "$@"; do
    case $option in
        --poweroff)
            echo "System will power off after updates and syncs."
            poweroff=true
            ;;
        --reboot)
            echo "System will reboot after updates and syncs."
            reboot=true
            ;;
        --update)
            echo "Running system update."
            update_system
            ;;
        *)
            echo "Unknown option: $option"
            ;;
    esac
done

if [[ -z "$1" ]]; then
    echo "No options specified. Running all functions."
    run_all_tasks
fi

if [ "$reboot" = true ]; then
    echo "Rebooting after updates and syncs."
    run_all_tasks
    wait_for_kernel_update_completion
    
    if command -v gnome-session-quit &> /dev/null; then
        gnome-session-quit --reboot
    else
        sudo reboot
    fi
fi

if [ "$poweroff" = true ]; then
    echo "Powering off after updates and syncs."
    run_all_tasks
    wait_for_kernel_update_completion
    if command -v gnome-session-quit &> /dev/null; then
        gnome-session-quit --power-off
    else
    sudo poweroff
fi
fi