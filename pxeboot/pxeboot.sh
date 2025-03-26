#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit
fi

echo "Updating system..."
dnf update -y

echo "Installing required packages..."
dnf install -y tftp-server dnsmasq syslinux xinetd

echo "Configuring TFTP server..."
cat > /etc/xinetd.d/tftp << EOF
service tftp
{
    socket_type = dgram
    protocol = udp
    wait = yes
    user = root
    server = /usr/sbin/in.tftpd
    server_args = -s /var/lib/tftpboot
    disable = no
}
EOF

echo "Creating TFTP root directory..."
mkdir -p /var/lib/tftpboot
chmod 755 /var/lib/tftpboot

echo "Restarting TFTP server..."
systemctl restart xinetd
systemctl enable xinetd

echo "Configuring dnsmasq..."
cat > /etc/dnsmasq.conf << EOF
interface=eth0
dhcp-range=192.168.1.100,192.168.1.200,12h
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=/var/lib/tftpboot
log-queries
log-dhcp
EOF

echo "Starting and enabling dnsmasq service..."
systemctl restart dnsmasq
systemctl enable dnsmasq

echo "Copying PXE bootloader files..."
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot

echo "Setting up PXE configuration..."
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cat > /var/lib/tftpboot/pxelinux.cfg/default << EOF
DEFAULT win98

LABEL win98
    MENU LABEL Install Windows 98
    KERNEL memdisk
    APPEND iso initrd=win98.iso
EOF

echo "Please place your Windows 98 ISO as 'win98.iso' in /var/lib/tftpboot"
echo "PXE boot server setup is complete!"

