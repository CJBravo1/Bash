#!/bin/bash
# Run this after OS install. This script will install some standard packages and set up some basic configurations.

# Set variables
ACTUAL_USER=$SUDO_USER
ACTUAL_HOME=$(eval echo ~$SUDO_USER)
LOG_DIR="$ACTUAL_HOME/.log"
LOG_FILE="$LOG_DIR/PostInstall.log"
mkdir -p "$LOG_DIR"

# Check if Flatpak is installed
FLATPAK_INSTALLED=false
if command -v flatpak >/dev/null 2>&1; then
    FLATPAK_INSTALLED=true
fi

####Functions####
###Script Functions###

echo_green () {
    echo -e "\e[32m$1\e[0m"
}

# Set key=value in a config file, replacing an existing entry instead of appending a duplicate
set_config_value() {
    local file="$1" key="$2" value="$3"
    if sudo grep -q "^${key}=" "$file"; then
        sudo sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" | sudo tee -a "$file" > /dev/null
    fi
}

get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

check_WINDOW_MANAGER() {
    # Look for an installed desktop rather than session env vars, which are
    # missing over SSH/sudo. A display manager or session files mean a DE exists.
    if [ -e /etc/systemd/system/display-manager.service ] \
        || compgen -G "/usr/share/xsessions/*.desktop" >/dev/null \
        || compgen -G "/usr/share/wayland-sessions/*.desktop" >/dev/null; then
        log_message "Window manager is installed"
        WINDOW_MANAGER=true
        return 0
    else
        log_message "No window manager detected"
        WINDOW_MANAGER=false
        return 1
    fi
}

handle_error() {
    local exit_code=$?
    local message="$1"
    if [ $exit_code -ne 0 ]; then
        log_message "ERROR: $message"
        exit $exit_code
    fi
}

log_message() {
    local message="$1"
    echo "$(get_timestamp) - $message" | tee -a "$LOG_FILE"
}


backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$file.bak"
        handle_error "Failed to backup $file"
        log_message "Backed up $file"
    fi
}

five_second_countdown() {
    echo "Rebooting in 5 seconds..."
    for i in {5..1}; do
        echo "$i"
        sleep 1
    done
}

gnome_check() {
    # Check the session env var, but fall back to looking for gnome-shell since
    # XDG_CURRENT_DESKTOP is usually stripped when the script runs under sudo/SSH.
    if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]] || command -v gnome-shell >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}



####Installation Functions####

installDocker(){
    curl -sSL https://get.docker.com | sh
}

installClaudeCode() {
    log_message "Installing Claude Code"
    if command -v claude >/dev/null 2>&1; then
        echo "Claude Code is already installed"
    else
        echo "Claude Code is not installed, installing..."
        curl -fsSL https://claude.ai/install.sh | bash
    fi
}


ensureFlathub() {
    # Make sure flatpak is installed and the Flathub remote is added and enabled.
    # Fedora Workstation only enables Flathub through GNOME's initial-setup
    # "third-party repositories" toggle; KDE and other spins never do, and Fedora
    # may ship the remote disabled/filtered, so fix it up explicitly everywhere.
    if ! command -v flatpak >/dev/null 2>&1; then
        echo_green "Installing Flatpak"
        if [ -f /etc/debian_version ]; then
            sudo apt install -y flatpak
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y flatpak
        fi
    fi

    log_message "Ensuring Flathub remote is enabled"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak remote-modify --enable --no-filter flathub
}

installFlatpacks() {
    log_message "Installing Flatpaks"
    ensureFlathub
    flatpaks=(
        #app.drey.Damask
        #com.dropbox.Client
        com.github.tchx84.Flatseal
        com.spotify.Client
        com.transmissionbt.Transmission
        #org.raspberrypi.rpi-imager
        io.github.davidoc26.wallpaper_selector
        io.github.sigmasd.stimulator
        io.missioncenter.MissionCenter
        #org.gnome.Firmware
        org.gnome.World.PikaBackup
        org.remmina.Remmina
    )

    # GNOME-only apps (useless on KDE and other desktops)
    if gnome_check; then
        flatpaks+=(
            com.mattjakeman.ExtensionManager
            io.github.realmazharhussain.GdmSettings
        )
    fi

    # Install all flatpaks at once
    echo_green "Installing ${flatpaks[@]}"  # Echo in green color
    # This command installs the Flatpaks specified in the 'flatpaks' array.
    flatpak install -y flathub "${flatpaks[@]}"
}

installGoogleChromeDeb() {
    log_message "Installing Google Chrome"
        if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
            # Install Google Chrome
            echo_green "Installing Google Chrome"  # Echo in green color
            wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
            sudo dpkg -i google-chrome-stable_current_amd64.deb
            sudo apt install -f -y
            rm google-chrome-stable_current_amd64.deb
        else
            echo "Google Chrome is already installed"
        fi
}

installGoogleChromeRpm() {
    log_message "Installing Google Chrome"
    echo_green "Installing Google Chrome"  # Echo in green color
    # Chrome is not in the Fedora repos. fedora-workstation-repositories ships this
    # repo file disabled, so write it out enabled.
    sudo rpm --import https://dl.google.com/linux/linux_signing_key.pub
    sudo tee /etc/yum.repos.d/google-chrome.repo > /dev/null <<'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
    sudo dnf install google-chrome-stable -y
    rpm -q google-chrome-stable >/dev/null 2>&1 || log_message "ERROR: Google Chrome did not install"
}

installMicrosoftFontsRpm() {
    # Arial, Times New Roman, Verdana and friends. Not in Fedora or RPM Fusion.
    # (mscore-* in Fedora is MuseScore, not Microsoft core fonts.)
    log_message "Installing Microsoft fonts"
    if fc-list 2>/dev/null | grep -qi "/msttcore/arial.ttf"; then
        echo "Microsoft fonts are already installed"
        return 0
    fi
    local url="https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm"
    local sha256="55d7f3a86533225634ff3ea2384b4356d9665a29cc7eeacff16602a1714afbb4"
    local tmp_dir
    tmp_dir=$(mktemp -d) || return 1
    sudo dnf install -y cabextract xorg-x11-font-utils fontconfig curl
    # The package predates RPM digests, which RPM 6 (Fedora 43+) requires, so dnf
    # refuses it. Check it against a fixed SHA-256 here, then skip RPM's own check.
    if curl -fsSL -o "$tmp_dir/msttcore.rpm" "$url" \
        && echo "$sha256  $tmp_dir/msttcore.rpm" | sha256sum -c --quiet -; then
        sudo rpm -U --replacepkgs --nodigest --nosignature "$tmp_dir/msttcore.rpm"
    else
        log_message "ERROR: Microsoft fonts download failed or did not match its SHA-256"
    fi
    rm -rf "$tmp_dir"
    sudo fc-cache -f
    fc-list | grep -qi "/msttcore/arial.ttf" || log_message "ERROR: Microsoft fonts did not install"
}

installMicrosoftFontsDeb() {
    # Same fonts as installMicrosoftFontsRpm. In contrib on Debian and multiverse on
    # Ubuntu and Mint.
    log_message "Installing Microsoft fonts"
    if fc-list 2>/dev/null | grep -qi "/msttcorefonts/arial.ttf"; then
        echo "Microsoft fonts are already installed"
        return 0
    fi
    local file
    if ! apt-cache policy ttf-mscorefonts-installer | grep -q 'Candidate: [0-9]'; then
        if grep -q '^ID=debian' /etc/os-release; then
            for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
                [ -f "$file" ] && sudo sed -i '/^deb.*debian\.org/{/contrib/!s/\bmain\b/main contrib/}' "$file"
            done
            for file in /etc/apt/sources.list.d/*.sources; do
                [ -f "$file" ] && grep -q 'debian\.org' "$file" \
                    && sudo sed -i '/^Components:/{/contrib/!s/\bmain\b/main contrib/}' "$file"
            done
        elif command -v add-apt-repository >/dev/null 2>&1; then
            sudo add-apt-repository -y multiverse
        fi
        sudo apt update
    fi
    # Accept the license up front, or the installer stops at a full-screen prompt
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections
    sudo apt install -y fontconfig ttf-mscorefonts-installer
    sudo fc-cache -f
    fc-list | grep -qi "/msttcorefonts/arial.ttf" || log_message "ERROR: Microsoft fonts did not install"
}

installGoogleChromeFlatpak() {
    echo_green "Installing Google Chrome"  # Echo in green color
    ensureFlathub
    flatpak install flathub com.google.Chrome -y
    flatpak override --user --filesystem=~/.local/share/applications --filesystem=~/.local/share/icons com.google.Chrome

}

installPowershell(){
    # Install PowerShell
    log_message "Installing PowerShell"
    if ! command -v pwsh >/dev/null 2>&1; then
        # Install PowerShell
        echo_green "Installing PowerShell"  # Echo in green color
        if [ -f /etc/debian_version ]; then
            # Install PowerShell for Debian-based systems
            # Update the list of packages
            sudo apt update

            # Install pre-requisite packages.
            sudo apt install -y wget

            # Get the version of Debian
            source /etc/os-release

            # Download the Microsoft repository GPG keys
            wget -q https://packages.microsoft.com/config/debian/$VERSION_ID/packages-microsoft-prod.deb

            # Register the Microsoft repository GPG keys
            sudo dpkg -i packages-microsoft-prod.deb

            # Delete the Microsoft repository GPG keys file
            rm packages-microsoft-prod.deb

            # Update the list of packages after we added packages.microsoft.com
            sudo apt update

            ###################################
            # Install PowerShell
            sudo apt install -y powershell

        elif [ -f /etc/redhat-release ]; then
            # Install PowerShell for Fedora
            # Get version of RHEL
            source /etc/os-release
            if [ ${VERSION_ID%.*} -lt 8 ]
            then majorver=7
            elif [ ${VERSION_ID%.*} -lt 9 ]
            then majorver=8
            else majorver=9
            fi

            # Download the Microsoft RedHat repository package
            curl -sSL -O https://packages.microsoft.com/config/rhel/$majorver/packages-microsoft-prod.rpm

            # Register the Microsoft RedHat repository
            sudo rpm -i packages-microsoft-prod.rpm

            # Delete the downloaded package after installing
            rm packages-microsoft-prod.rpm

            # Update package index files
            sudo dnf update
            # Install PowerShell
            sudo dnf install powershell -y
        fi
    else
        echo "PowerShell is already installed"
    fi
}


install_tailscale_gnome_extension() {
    echo "==> Installing Tailscale QS GNOME extension..."

    # Get the installed GNOME Shell major version
    local GNOME_VERSION
    GNOME_VERSION=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)
    echo "  -> Detected GNOME Shell version: $GNOME_VERSION"

    # Query the extensions.gnome.org API to get the correct version_tag (pk)
    # for this GNOME Shell version
    echo "  -> Querying extensions.gnome.org for compatible version..."
    local EXT_INFO VERSION_TAG
    EXT_INFO=$(curl -fsSL \
        "https://extensions.gnome.org/extension-info/?uuid=tailscale@joaophi.github.com&shell_version=${GNOME_VERSION}")

    VERSION_TAG=$(echo "$EXT_INFO" | python3 -c "
import sys, json
data = json.load(sys.stdin)
svm = data.get('shell_version_map', {})
key = '$GNOME_VERSION'
if key in svm:
    print(svm[key]['pk'])
else:
    # Fall back to highest available version
    latest = sorted(svm.items(), key=lambda x: float(x[0]))[-1]
    print(latest[1]['pk'])
")

    if [ -z "$VERSION_TAG" ]; then
        echo "ERROR: Could not determine version_tag from extensions.gnome.org" >&2
        return 1
    fi
    echo "  -> Using version_tag: $VERSION_TAG"

    # Download the extension zip using the correct version_tag
    echo "  -> Downloading Tailscale QS..."
    curl -fsSL \
        "https://extensions.gnome.org/download-extension/tailscale@joaophi.github.com.shell-extension.zip?version_tag=${VERSION_TAG}" \
        -o /tmp/tailscale-qs.zip

    # Install and enable using the official gnome-extensions CLI
    echo "  -> Installing extension..."
    gnome-extensions install --force /tmp/tailscale-qs.zip

    echo "  -> Enabling extension..."
    gnome-extensions enable tailscale@joaophi.github.com

    # Clean up
    rm -f /tmp/tailscale-qs.zip

    # Required: set current user as Tailscale operator
    echo "  -> Setting $USER as Tailscale operator..."
    sudo tailscale set --operator="$USER"

    echo "==> Done! Tailscale QS installed."
    echo "    Log out and back in to activate (X11: Alt+F2 -> 'r' to restart GNOME Shell)."
}


install_tailscale() {
    log_message "Installing Tailscale"
    if ! command -v tailscale >/dev/null 2>&1; then
        echo_green "Installing Tailscale"  # Echo in green color
        curl -fsSL https://tailscale.com/install.sh | sh
    else
        echo "Tailscale is already installed"
    fi
}

installVSCodeRPM()
{
        #Install VSCode
    echo_green "Installing Visual Studio Code"  # Echo in green color
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    dnf check-update
    sudo dnf install code -y
}

installVSCodeDeb(){
    echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
    sudo apt -y install wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    sudo apt install apt-transport-https
    sudo apt update
    sudo apt install -y code # or code-insiders


}

###Customization Functions###

addGreetings() {
    #Copy bash_aliases and bash_functions
    echo_green " Adding Bash functions and aliases"
    cat ~/Scripts/bash/Post\ Install/.bashrc >> ~/.bashrc 
    cp -v ~/Scripts/bash/Post\ Install/.bash_aliases ~/
    cp -v ~/Scripts/bash/Post\ Install/.bash_functions ~/
    cp -v ~/Scripts/bash/Post\ Install/updatescript.sh ~/
}

# Enable an extension. gnome-extensions can't see one installed in this session
# until the next login, so fall back to adding it to the enabled list directly.
enable_gnome_extension() {
    local uuid="$1" current
    gnome-extensions enable "$uuid" 2>/dev/null && return 0
    current=$(gsettings get org.gnome.shell enabled-extensions)
    case "$current" in
        *"'$uuid'"*) ;;
        "@as []"|"[]") gsettings set org.gnome.shell enabled-extensions "['$uuid']" ;;
        *) gsettings set org.gnome.shell enabled-extensions "${current%]}, '$uuid']" ;;
    esac
}

# Ulauncher is in Fedora's repos but not in Debian's or Ubuntu's, so use the .deb
# from its latest stable GitHub release there.
installUlauncherDeb() {
    local url tmp_dir
    url=$(curl -fsSL https://api.github.com/repos/Ulauncher/Ulauncher/releases/latest \
        | grep -oE 'https://[^"]+_all\.deb' | head -n1)
    tmp_dir=$(mktemp -d) || return 1
    chmod 755 "$tmp_dir"   # apt's sandbox user has to read the file
    if [ -n "$url" ] && curl -fsSL -o "$tmp_dir/ulauncher.deb" "$url"; then
        sudo apt install -y "$tmp_dir/ulauncher.deb"
    else
        log_message "ERROR: could not download Ulauncher"
    fi
    rm -rf "$tmp_dir"
}

customize_gnome() {
    # Customize GNOME settings
    log_message "Customizing GNOME settings"
    gsettings set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"

    # Sort files by Type in the default folder view
    gsettings set org.gnome.nautilus.preferences default-sort-order type

    # Dash to Dock: package names differ, and Ubuntu's own dock is a fork of it
    local dock_installed=true
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y --skip-unavailable gnome-tweaks gnome-shell-extension-dash-to-dock
    elif command -v apt >/dev/null 2>&1; then
        sudo apt install -y gnome-tweaks
        if [ -d /usr/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com ]; then
            log_message "Ubuntu Dock is present, skipping Dash to Dock"
            dock_installed=false
        else
            sudo apt install -y gnome-shell-extension-dashtodock
        fi
    fi
    if $dock_installed; then
        enable_gnome_extension dash-to-dock@micxgx.gmail.com
    fi

    #Install Ulauncher
    if ! command -v ulauncher >/dev/null 2>&1; then
        echo "Installing Ulauncher"
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y ulauncher
        elif command -v apt >/dev/null 2>&1; then
            installUlauncherDeb
        fi
    else
        echo "Ulauncher is already installed"
    fi

    if ! command -v ulauncher >/dev/null 2>&1; then
        log_message "ERROR: Ulauncher did not install, skipping its keyboard shortcut"
        return 1
    fi

    # Set keyboard shortcut Super+Space to launch Ulauncher
    echo "Setting keyboard shortcut Super+Space for Ulauncher"

    # Remove existing custom keybindings using Super+Space
    for kb_path in $(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings | tr -d "[],'"); do
        if [ -n "$kb_path" ]; then
            current_binding=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${kb_path} binding 2>/dev/null)
            if [ "$current_binding" = "'<Super>space'" ] || [ "$current_binding" = "'<Super>Space'" ]; then
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${kb_path} binding "''"
            fi
        fi
    done

    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name "Ulauncher"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "ulauncher-toggle"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding "<Super>space"

}



####OS Specific Functions####
installDebian() {    
    log_message "Performing system upgrade... This may take a while..."
    # Start with Updates
    echo "Running: sudo apt update"
    sudo apt update
    echo "Running: sudo apt upgrade -y"
    sudo apt upgrade -y
    # Install Standard Packages
    echo "Running: sudo apt install toilet fortune lolcat vim nano htop -y"
    sudo apt install -y\
    borgbackup\
    btop\
    curl\
    fortune\
    gh\
    htop\
    lolcat\
    nano\
    nfs-common\
    toilet\
    vim

    # Check if a window manager is installed
    if check_WINDOW_MANAGER; then
        # Desktop-only packages
        sudo apt install -y gnome-firmware
        installMicrosoftFontsDeb

        # Flatpak + Flathub are set up by ensureFlathub (called from installFlatpacks)
        ensureFlathub
    else
        echo "No window manager detected, skipping Flatpak installation"
    fi

    # Check if the computer is a Raspberry Pi and install Cockpit for remote management
    if [ "$(uname -m)" = "armv7l" ]; then
        # Install Cockpit
        # Ask if the user wants to install Cockpit
        read -p "Do you want to install Cockpit for remote management? (y/n): " install_cockpit
        if [ "$install_cockpit" = "y" ]; then
            # Install Cockpit
            echo "Installing Cockpit"
            sudo apt install cockpit -y
            sudo systemctl enable --now cockpit.socket
            echo "Cockpit is now available at https://$(hostname -I | awk '{print $1}'):9090"
        fi
    fi
    
}

###Redhat###
installFedora() {

    # Set DNF Parallel Downloads
    sudo cp "/etc/dnf/dnf.conf" "/etc/dnf/dnf.conf.bak"
    set_config_value /etc/dnf/dnf.conf max_parallel_downloads 10
    set_config_value /etc/dnf/dnf.conf fastestmirror True
    sudo dnf -y install dnf-plugins-core
    
    if rpm -q firefox >/dev/null 2>&1; then
        sudo dnf remove firefox -y
    fi
    if rpm -q libreoffice >/dev/null 2>&1; then
        sudo dnf remove libreoffice-* -y
    fi

    # Set DNF Default to Yes
    sudo sed -i 's/^#default_yes=default_no/default_yes=default_yes/' /etc/dnf/dnf.conf

    # Enable RPM Fusion repositories to access additional software packages and codecs
    sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    dnf group update core -y

    # Start with Updates
    echo "Running: sudo dnf makecache"
    sudo dnf makecache
    echo "Running: sudo dnf update -y"
    sudo dnf update -y

    # Install Standard Packages
    echo "Running: Standard Package Installs"
    sudo dnf install -y \
        borgbackup \
        btop \
        fastfetch \
        fortune-mod \
        gh \
        htop \
        lolcat \
        nano \
        pv \
        rclone \
        toilet \
        tmux \
        vim

    # Desktop-only packages
    if $WINDOW_MANAGER; then
        # --skip-unavailable: one missing package must not block the others
        sudo dnf install -y --skip-unavailable \
            gnome-firmware \
            gparted
        installMicrosoftFontsRpm
    fi


    # Check for firmware updates
    log_message "Checking for firmware updates..."
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates
    sudo fwupdmgr update -y

    # Check if the OS is running as a virtual machine
    if grep -qE "(vmware|virtualbox|qemu|kvm|xen|hyper-v)" /proc/cpuinfo || systemd-detect-virt -q; then
        sudo plymouth-set-default-theme tribar -R
    else
        log_message "Not running inside a virtual machine."
    fi
}

# Print each LUKS UUID named by rd.luks.uuid= on the kernel command line.
# Accepts both rd.luks.uuid=luks-<uuid> and rd.luks.uuid=<uuid>.
luks_uuids_from_cmdline() {
  local cmdline_file="${1:-/proc/cmdline}"
  xargs -n1 -a "$cmdline_file" | sed -n 's/^rd\.luks\.uuid=//p' | sed 's/^luks-//' | sort -u
}

# Print the keyslots used by systemd-tpm2 tokens, comma separated.
# --disable-external-tokens is needed: with systemd 262 the token plugin moves
# the rest of the luksDump output to stderr.
luks_tpm2_keyslots() {
  sudo cryptsetup luksDump --disable-external-tokens "$1" | awk '
    /^  [0-9]+: systemd-tpm2$/ { f=1; next }
    /^  [0-9]+: /              { f=0 }
    f && /Keyslot:/            { print $2; f=0 }' | paste -sd, -
}

# Set the key file field to none and add tpm2-device=auto for one volume.
# A key file left in the third field stops the TPM unlock being used at boot.
update_crypttab_tpm() {
  local uuid="$1" crypttab_file="${2:-/etc/crypttab}"
  local new_file="$crypttab_file.new"

  if ! sudo awk -v uuid="$uuid" '
      !/^[[:space:]]*#/ && ($1 == "luks-" uuid || $2 == "UUID=" uuid) { found=1 }
      END { exit !found }' "$crypttab_file"; then
    log_message "Could not find LUKS volume $uuid in $crypttab_file"
    return 1
  fi

  sudo cp -a "$crypttab_file" "$crypttab_file.bak" || return 1
  sudo awk -v uuid="$uuid" '
    !/^[[:space:]]*#/ && ($1 == "luks-" uuid || $2 == "UUID=" uuid) {
      $3 = "none"
      if ($4 == "" || $4 == "none") $4 = "tpm2-device=auto"
      else if ($4 !~ /(^|,)tpm2-device=/) $4 = $4 ",tpm2-device=auto"
    }
    { print }' "$crypttab_file" | sudo tee "$new_file" > /dev/null || return 1

  if ! sudo test -s "$new_file"; then
    sudo rm -f "$new_file"
    log_message "Failed to write $new_file. $crypttab_file was not changed."
    return 1
  fi

  sudo chmod 600 "$new_file"
  sudo mv "$new_file" "$crypttab_file" || return 1
  command -v restorecon >/dev/null 2>&1 && sudo restorecon "$crypttab_file"
  log_message "Set tpm2-device=auto in $crypttab_file for luks-$uuid"
}

# Enroll one LUKS volume into the TPM and update crypttab.
enroll_luks_device() {
  local uuid="$1"
  local crypt_disk="/dev/disk/by-uuid/$uuid"
  local wipe_args=() tpm2_slots answer

  if [[ ! -L "$crypt_disk" ]]; then
    printf "LUKS device %s not listed in block devices.\n" "$crypt_disk"
    return 1
  fi

  if ! sudo cryptsetup isLuks --type luks2 "$crypt_disk"; then
    printf "%s is not LUKS2. TPM enrollment needs LUKS2.\n" "$crypt_disk"
    return 1
  fi

  # Clevis cannot find its tokens once systemd-tpm2 tokens share the header
  if sudo cryptsetup luksDump --disable-external-tokens "$crypt_disk" | grep -qE '^  [0-9]+: clevis$'; then
    echo -e "\e[31mClevis is bound to $crypt_disk. With systemd 262 clevis stops working once a systemd-tpm2 token is present.\e[0m"
    read -p "Continue with TPM enrollment anyway? (y/n): " answer
    if [ "$answer" != "y" ]; then
      echo "Skipping $crypt_disk"
      return 1
    fi
  fi

  tpm2_slots=$(luks_tpm2_keyslots "$crypt_disk")
  if [ -n "$tpm2_slots" ]; then
    echo "TPM2 already present in LUKS keyslot(s) $tpm2_slots of $crypt_disk. Replacing it after the new enrollment succeeds."
    wipe_args=(--wipe-slot=tpm2)
  fi

  # Combined on purpose: systemd-cryptenroll enrolls first and only then wipes,
  # so a failed enrollment leaves the existing TPM slot in place.
  echo_green "Enrolling TPM2 unlock requires your existing LUKS2 unlock password"
  if ! sudo systemd-cryptenroll "${wipe_args[@]}" --tpm2-device=auto --tpm2-pcrs=7+14 "$crypt_disk"; then
    log_message "TPM2 enrollment failed for $crypt_disk. crypttab was not changed."
    return 1
  fi

  update_crypttab_tpm "$uuid"
}

#Auto Enroll LUKS key into TPM
enroll_luks_tpm() {

  # The steps below rely on dracut or rpm-ostree. Debian's initramfs-tools
  # does not support tpm2-device= in crypttab.
  if [ ! -e /run/ostree-booted ] && ! command -v dracut >/dev/null 2>&1; then
    printf "TPM enrollment here needs dracut or rpm-ostree. Neither was found.\n"
    return 1
  fi

  if [ ! -c /dev/tpmrm0 ]; then
    printf "No TPM2 device found (/dev/tpmrm0).\n"
    return 1
  fi

  ## Find the LUKS volumes the kernel unlocks at boot
  local uuids=() uuid enrolled=0 failed=0
  mapfile -t uuids < <(luks_uuids_from_cmdline)

  if [ "${#uuids[@]}" -eq 0 ]; then
    printf "No rd.luks.uuid= found on the kernel command line.\n"
    printf "This is not supported by this script.\n"
    return 1
  fi

  ## dracut's tpm2-tss module needs the tpm2 binary from tpm2-tools.
  ## Without it the TPM libraries are left out of the initramfs.
  if [ ! -e /run/ostree-booted ] && command -v dnf >/dev/null 2>&1; then
    if ! sudo dnf install -y tpm2-tools tpm2-tss; then
      log_message "Failed to install tpm2-tools and tpm2-tss"
      return 1
    fi
  fi
  if ! command -v tpm2 >/dev/null 2>&1; then
    printf "tpm2-tools is not installed. Install it and rerun.\n"
    return 1
  fi

  for uuid in "${uuids[@]}"; do
    if enroll_luks_device "$uuid"; then
      enrolled=$((enrolled + 1))
    else
      failed=$((failed + 1))
    fi
  done

  if [ "$enrolled" -eq 0 ]; then
    log_message "No LUKS volumes were enrolled."
    return 1
  fi

  ## Make sure the initramfs includes tpm2-tss so it can unlock at boot
  if [ -e /run/ostree-booted ]; then
    sudo rpm-ostree initramfs --enable --arg=--force-add --arg=tpm2-tss
    log_message "Enabled rpm-ostree initramfs with tpm2-tss."
  else
    # Persist the module so future kernel updates keep it
    echo 'add_dracutmodules+=" tpm2-tss "' | sudo tee /etc/dracut.conf.d/tpm2.conf > /dev/null
    # Every kernel: this script updates first, so the next boot may use a newer one
    if ! sudo dracut --force --regenerate-all; then
      log_message "dracut failed. The initramfs may not include the crypttab change."
      return 1
    fi
    log_message "Regenerated initramfs with dracut."

    if command -v update-grub >/dev/null 2>&1; then
      sudo update-grub
      log_message "Updated GRUB bootloader."
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
      sudo grub2-mkconfig -o /boot/grub2/grub.cfg
      log_message "Updated GRUB2 bootloader."
    fi
  fi

  ## Now reboot
  echo
  if [ "$failed" -gt 0 ]; then
    log_message "TPM2 enrollment failed for $failed LUKS volume(s). Those volumes will still ask for a password."
    return 1
  fi
  echo_green "TPM2 LUKS auto-unlock configured."
}


installSilverblue() {
    # Set rpm-ostree parallel downloads
    sudo cp "/etc/rpm-ostree.conf" "/etc/rpm-ostree.conf.bak"
    set_config_value /etc/rpm-ostree.conf max_parallel_downloads 10

    # Enable RPM Fusion repositories for Silverblue
    rpm-ostree install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    rpm-ostree install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    # Update the system
    echo "Running: rpm-ostree upgrade"
    sudo rpm-ostree upgrade

    # Install Standard Packages
    echo "Running: Standard Package Installs"
    rpm-ostree install toilet borgbackup fortune-mod lolcat vim nano htop btop gh pv fastfetch gnome-firmware rclone

    # Remove unwanted packages
    echo "Removing unwanted packages"
    if rpm -q firefox >/dev/null 2>&1; then
        rpm-ostree override remove firefox
    else
        echo "Firefox is not installed"
    fi

    if rpm -q libreoffice >/dev/null 2>&1; then
        rpm-ostree override remove libreoffice
    else
        echo "LibreOffice is not installed"
    fi

    # Check for firmware updates
    log_message "Checking for firmware updates..."
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates
    sudo fwupdmgr update -y

    # Check if the OS is running as a virtual machine
    if grep -qE "(vmware|virtualbox|qemu|kvm|xen|hyper-v)" /proc/cpuinfo || systemd-detect-virt -q; then
        sudo plymouth-set-default-theme tribar -R
    else
        log_message "Not running inside a virtual machine."
    fi

    # Apply pending changes and reboot
    echo "Applying changes and rebooting..."
    sudo rpm-ostree finalize 
    sudo rpm-ostree cleanup -m
}


#####START OF SCRIPT#####
check_WINDOW_MANAGER

# Clone the Bash Scripts repository
if ! command -v git >/dev/null 2>&1; then
    echo "git is not installed. Please install git and rerun the script."
    exit 1
fi

if [ -d $ACTUAL_HOME/Scripts/bash ]; then
    echo "Bash directory already exists"
else
    echo "Cloning Bash Scripts repository"
    mkdir -p ~/Scripts
    git clone https://github.com/cjbravo1/bash ~/Scripts/bash
    POST_INSTALL_DIR=$ACTUAL_HOME/Scripts/bash/Post\ Install
fi

# Check if the OS is Debian-based
if [ -f /etc/debian_version ]; then
    installDebian

    if $WINDOW_MANAGER; then
        #if $FLATPAK_INSTALLED; then
            #Install Google Chrome
         #   installGoogleChromeFlatpak
        #else
            installGoogleChromeDeb
        #fi
    fi
fi

# Check if the OS is Fedora (excluding ostree-based Silverblue/Kinoite)
if [ -f /etc/redhat-release ] && [ ! -e /run/ostree-booted ]; then
    installFedora

    if $WINDOW_MANAGER; then
        #if $FLATPAK_INSTALLED; then
            #Install Google Chrome
        #    installGoogleChromeFlatpak
        #else
            installGoogleChromeRpm
       # fi
    fi
fi
 
# Check if the OS is Silverblue
if [ -f /etc/os-release ] && grep -qE "Silverblue|Kinoite" /etc/os-release; then
    if grep -q "Fedora" /etc/os-release; then
        installSilverblue
        if $WINDOW_MANAGER; then
            #Install Google Chrome
            installGoogleChromeFlatpak
        fi
    fi
fi

# Install Flatpacks
if $WINDOW_MANAGER; then
    # Install Flatpacks
    echo_green "Installing Flatpacks"  # Echo in green color
    installFlatpacks
    # Customize GNOME if it's the window manager
    if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
        customize_gnome
    fi
fi

### Optional Configurations ###

#Set Hostname
read -p "Do you want to set the hostname? (y/n): " set_hostname
if [ "$set_hostname" = "y" ]; then
    read -p "Enter the new hostname: " new_hostname
    sudo hostnamectl set-hostname "$new_hostname"
    log_message "Hostname set to $new_hostname"
fi

# Enroll LUKS key into TPM
read -p "Do you want to enroll LUKS key into TPM? (y/n): " enroll_tpm
if [ "$enroll_tpm" = "y" ]; then
    if command -v systemd-cryptenroll >/dev/null 2>&1; then
        enroll_luks_tpm
    else
        echo "systemd-cryptenroll is not installed. Please install it and rerun the script."
    fi
fi

### Optional Installs ###

#Install Visual Studio Code
if $WINDOW_MANAGER; then
    read -p "Do you want to install Visual Studio Code? (y/n): " install_vscode
    if [ "$install_vscode" = "y" ]; then
        if [ -f /etc/debian_version ]; then
            installVSCodeDeb
        elif [ -f /etc/redhat-release ]; then
            installVSCodeRPM
        fi
    fi
fi

# Install Docker
read -p "Do you want to install Docker? (y/n): " install_docker
if [ "$install_docker" = "y" ]; then
    installDocker
fi

# Check if the user wants to install Claude Code
read -p "Do you want to install Claude Code? (y/n): " install_claude
if [ "$install_claude" = "y" ]; then
    installClaudeCode
fi

# Install Tailscale
read -p "Do you want to install Tailscale? (y/n): " install_tailscale
if [ "$install_tailscale" = "y" ]; then
    install_tailscale
    if $WINDOW_MANAGER && [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
        install_tailscale_gnome_extension
    fi
fi

#Install Steam
if $WINDOW_MANAGER; then
    read -p "Do you want to install Steam? (y/n): " install_steam
    if [ "$install_steam" = "y" ]; then
        if [ -f /etc/debian_version ]; then
            sudo apt install steam -y
        elif [ -f /etc/redhat-release ]; then
            sudo dnf install steam -y
        fi
    fi
fi

#Install Powershell
read -p "Do you want to install PowerShell? (y/n): " install_powershell
if [ "$install_powershell" = "y" ]; then
    installPowershell
fi

# Create SSH Keys
if [ -f ~/.ssh/id_ed25519 ]; then
    echo "SSH key already exists, skipping"
else
    echo "Creating SSH Keys"
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
fi

# Add Bash Greetings
addGreetings

#Restart the shell
source ~/.bashrc

# End of Script
echo_green "End of Script"