#!/bin/bash

install_shairport() {
    #Install Shairport (AirPlay)
    sudo apt update && sudo apt install autoconf automake avahi-daemon build-essential git libasound2-dev libavahi-client-dev libconfig-dev libdaemon-dev libpopt-dev libssl-dev libtool xmltoman
    git clone https://github.com/mikebrady/shairport-sync.git
    cd shairport-sync
    autoreconf -i -f
    ./configure --with-alsa --with-avahi --with-ssl=openssl --with-systemd --with-metadata
    make
    sudo make install
}

install_raspotify() {
    #Install Raspotify (Spotify Connect)
    sudo apt install -y apt-transport-https curl
    curl -sSL https://dtcooper.github.io/raspotify/key.asc | sudo apt-key add -v -
    echo 'deb https://dtcooper.github.io/raspotify raspotify main' | sudo tee /etc/apt/sources.list.d/raspotify.list
    sudo apt update
    sudo apt install raspotify
}

install_bluetooth_audio() {
    #Install Bluetooth Audio ALSA Backend (bluez-alsa-utils)
    sudo apt update
    sudo apt install -y --no-install-recommends bluez-tools bluez-alsa-utils

    # Bluetooth settings
    sudo tee /etc/bluetooth/main.conf >/dev/null <<'EOF'
[General]
Class = 0x200414
DiscoverableTimeout = 0

[Policy]
AutoEnable=true
EOF

    # Bluetooth Agent
    sudo tee /etc/systemd/system/bt-agent@.service >/dev/null <<'EOF'
[Unit]
Description=Bluetooth Agent
Requires=bluetooth.service
After=bluetooth.service

[Service]
ExecStartPre=/usr/bin/bluetoothctl discoverable on
ExecStartPre=/bin/hciconfig %I piscan
ExecStartPre=/bin/hciconfig %I sspmode 1
ExecStart=/usr/bin/bt-agent --capability=NoInputNoOutput
RestartSec=5
Restart=always
KillSignal=SIGUSR1

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable bt-agent@hci0.service

    # Bluetooth udev script
    sudo tee /usr/local/bin/bluetooth-udev >/dev/null <<'EOF'
#!/bin/bash
if [[ ! $NAME =~ ^\"([0-9A-F]{2}[:-]){5}([0-9A-F]{2})\"$ ]]; then exit 0; fi

action=$(expr "$ACTION" : "\([a-zA-Z]\+\).*")

if [ "$action" = "add" ]; then
    bluetoothctl discoverable off
    # disconnect wifi to prevent dropouts
    #ifconfig wlan0 down &
fi

if [ "$action" = "remove" ]; then
    # reenable wifi
    #ifconfig wlan0 up &
    bluetoothctl discoverable on
fi
EOF
    sudo chmod 755 /usr/local/bin/bluetooth-udev

    sudo tee /etc/udev/rules.d/99-bluetooth-udev.rules >/dev/null <<'EOF'
SUBSYSTEM=="input", GROUP="input", MODE="0660"
KERNEL=="input[0-9]*", RUN+="/usr/local/bin/bluetooth-udev"
EOF
}

add_functions() {
    # Add aliases and functions from external files
    for file in bash_aliases bash_functions; do
        url="https://raw.githubusercontent.com/CJBravo1/Bash/refs/heads/master/Raspberry%20Pi/Airwave/$file"
        local_file="$HOME/.$file"
        if ! grep -q "$(curl -sSL $url)" $local_file; then
            echo -e "\e[32mAdding Aliases to .bash_aliases\e[0m"
            echo -e "\e[32mAdding Functions to .bash_functions\e[0m"
            curl -sSL $url -o $local_file
        fi
    done

    source ~/.bash_functions
    source ~/.bash_aliases
}


install_shairport
cd
install_raspotify
cd
install_bluetooth_audio

add_functions

#Cleanup
sudo apt autoremove -y