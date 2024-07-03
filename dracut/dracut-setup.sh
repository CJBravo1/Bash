#!/bin/bash

# Variables
DRACUT_CONF_DIR="/etc/dracut.conf.d"
DROPBEAR_CONF_FILE="${DRACUT_CONF_DIR}/dropbear.conf"
NETWORK_CONF_FILE="${DRACUT_CONF_DIR}/network.conf"
CRYPTTAB_FILE="/etc/crypttab"
GRUB_CONFIG_FILE="/boot/grub2/grub.cfg"
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"
IP_CONFIG="192.168.100.234::192.168.1.1:255.255.255.0:hostname:eth0:none"
SSH_PUBLIC_KEY="your_public_key_here"

# Ensure necessary packages are installed
echo "Installing necessary packages..."
dnf install -y dracut cryptsetup dropbear

# Create Dracut configuration directory if it doesn't exist
if [ ! -d "${DRACUT_CONF_DIR}" ]; then
  echo "Creating Dracut configuration directory..."
  mkdir -p "${DRACUT_CONF_DIR}"
fi

# Create Dracut configuration file for Dropbear
echo "Creating Dracut configuration file for Dropbear..."
cat <<EOL > "${DROPBEAR_CONF_FILE}"
add_dracutmodules+=" dropbear "
install_items+=" /root/.ssh/authorized_keys "
EOL

# Create Dracut network configuration file
echo "Creating Dracut network configuration file..."
cat <<EOL > "${NETWORK_CONF_FILE}"
ip=${IP_CONFIG}
EOL

# Create Dropbear Dracut module directory
echo "Creating Dropbear Dracut module directory..."
mkdir -p /usr/lib/dracut/modules.d/99dropbear

# Create Dropbear module setup script
echo "Creating Dropbear module setup script..."
cat <<'EOL' > /usr/lib/dracut/modules.d/99dropbear/module-setup.sh
#!/bin/bash

check() {
    require_binaries dropbear /usr/sbin/dropbear || return 1
    return 0
}

depends() {
    echo "network"
    return 0
}

install() {
    inst_multiple /usr/sbin/dropbear /usr/bin/dropbearkey /usr/bin/dropbearconvert /etc/dropbear
    inst_simple "$moddir/authorized_keys" "/root/.ssh/authorized_keys"
    inst_simple "$moddir/dropbear.service" "$systemdsystemunitdir/dropbear.service"
    inst_hook cmdline 30 "$moddir/parse-dropbear.sh"
}
EOL

# Create Dropbear authorized keys file
echo "Creating Dropbear authorized keys file..."
cat <<EOL > /usr/lib/dracut/modules.d/99dropbear/authorized_keys
${SSH_PUBLIC_KEY}
EOL

# Create Dropbear systemd service file
echo "Creating Dropbear systemd service file..."
cat <<'EOL' > /usr/lib/dracut/modules.d/99dropbear/dropbear.service
[Unit]
Description=Dropbear SSH server in initramfs
Before=network.target

[Service]
ExecStart=/usr/sbin/dropbear -E -m
StandardInput=tty-force

[Install]
WantedBy=initrd.target
EOL

# Create Dropbear parse script
echo "Creating Dropbear parse script..."
cat <<'EOL' > /usr/lib/dracut/modules.d/99dropbear/parse-dropbear.sh
#!/bin/bash

if getarg rd.neednet=1; then
    systemctl start dropbear.service
fi
EOL

# Make the Dropbear scripts executable
echo "Making Dropbear scripts executable..."
chmod +x /usr/lib/dracut/modules.d/99dropbear/module-setup.sh
chmod +x /usr/lib/dracut/modules.d/99dropbear/parse-dropbear.sh

# Ensure /root/.ssh directory exists and set permissions
echo "Setting up SSH authorized keys..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat <<EOL > "${AUTHORIZED_KEYS}"
${SSH_PUBLIC_KEY}
EOL
chmod 600 "${AUTHORIZED_KEYS}"

# Get UUID of the LUKS partition
echo "Finding UUID of LUKS partition..."
LUKS_UUID=$(lsblk -o UUID,TYPE | grep crypt | awk '{print $1}')
if [ -z "${LUKS_UUID}" ]; then
  echo "Error: No LUKS partition found."
  exit 1
fi

# Update /etc/crypttab
echo "Updating /etc/crypttab..."
if ! grep -q "UUID=${LUKS_UUID}" "${CRYPTTAB_FILE}"; then
  echo "luks-${LUKS_UUID} UUID=${LUKS_UUID} none luks" >> "${CRYPTTAB_FILE}"
fi

# Rebuild the initramfs
echo "Rebuilding the initramfs..."
dracut -f --regenerate-all

# Update GRUB configuration
echo "Updating GRUB configuration..."
grub2-mkconfig -o "${GRUB_CONFIG_FILE}"

# Reboot the system
echo "Rebooting the system..."
reboot
