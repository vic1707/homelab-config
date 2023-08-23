#!/bin/sh

################
## Min config ##
# 1 vCPU       #
# 32 MB RAM    #
# 0 MB SWAP    #
# 1 GB HDD     #
################

############ Variables ############
ROUTER_PRIVATE_MASK=255.255.255.240
ROUTER_PRIVATE_IP=10.0.0.1
DHCP_LEASE_TIME=12h
DHCP_LEASE_START=10.0.0.2
DHCP_LEASE_END=10.0.0.14
DNS_SERVERS=1.1.1.1,8.8.8.8

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
  address $ROUTER_PRIVATE_IP
  netmask $ROUTER_PRIVATE_MASK
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
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Save iptables rules
/etc/init.d/iptables save
rc-update add iptables
rc-service iptables start

# Configure DHCP
echo "Configuring DHCP..."
cat << EOF > /etc/dnsmasq.conf
interface=eth1
dhcp-range=$DHCP_LEASE_START,$DHCP_LEASE_END,$ROUTER_PRIVATE_MASK,$DHCP_LEASE_TIME
dhcp-option=option:router,$ROUTER_PRIVATE_IP
dhcp-option=option:dns-server,$DNS_SERVERS
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
