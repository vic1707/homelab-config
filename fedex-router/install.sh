#!/bin/sh

################
## Min config ##
# 1 vCPU       #
# 32 MB RAM    #
# 0 MB SWAP    #
# 1 GB HDD     #
################

# Install packages
echo "Updating repositories and installing packages..."
apk update
apk upgrade
apk add --no-cache dnsmasq iptables bottom

# Configure eth1
echo "Configuring eth1 interface..."
cat << EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
  address 10.10.1.1
  netmask 255.255.255.0
EOF

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Disable ipv6
echo "Disabling IPv6..."
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf

# custom init script
cat << EOF > /etc/local.d/sysctl.start
#!/bin/sh
/sbin/sysctl -p
EOF
chmod +x /etc/local.d/sysctl.start
rc-update add local default

# Configure iptables
echo "Configuring iptables..."
iptables -F
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth1 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Save iptables rules
/etc/init.d/iptables save
rc-update add iptables
rc-service iptables start

# Configure DHCP
echo "Configuring DHCP..."
cat << EOF > /etc/dnsmasq.conf
interface=eth1
dhcp-range=10.10.1.10,10.10.1.20,255.255.255.0,24h
dhcp-option=option:router,10.10.1.1
dhcp-option=option:dns-server,1.1.1.1, 8.8.4.4
EOF
rc-update add dnsmasq
rc-service dnsmasq start

# Reboot confirmation
echo "Configuration completed. Do you want to reboot now? (Y/N)"
read -r choice
if [ "$choice" = "Y" ] || [ "$choice" = "y" ]; then
  echo "Rebooting..."
  sleep 3
  reboot
else
  echo "Reboot cancelled. You can manually reboot the system when ready."
fi
