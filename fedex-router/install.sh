#!/bin/sh

################
## Min config ##
# 1 vCPU       #
# 64 MB RAM    #
# 0 MB SWAP    #
# 1 GB HDD     #
################

############ Variables ############
ROUTER_PRIVATE_MASK=255.255.255.240 # 28-bit netmask
ROUTER_PRIVATE_IP=10.0.0.1
DHCP_LEASE_TIME=12h
DHCP_LEASE_START=10.0.0.6
DHCP_LEASE_END=10.0.0.14
DNS_SERVERS=1.1.1.1,8.8.8.8
# ETH0_ADDR=$(ip addr show dev eth0 | grep "inet " | awk '{print $2}')
ETH0_NETWORK="$(ip route | awk '/eth0/ && !/default/ {print $1}')"
####### Static clients #######
BHULK_MAC=F6:3A:7B:43:B8:2C
BHULK_IP=10.0.0.2
#
MARINA_PROD_MAC=0A:A8:F3:7E:9D:64
MARINA_PROD_IP=10.0.0.3
#
# MARINA_STAGING_MAC=00:00:00:00:00:00
# MARINA_STAGING_IP=10.0.0.4
#
# MARINA_RANDOM_MAC=00:00:00:00:00:00
# MARINA_RANDOM_IP=10.0.0.5
###################################

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

# custom init script
cat << EOF > /etc/local.d/sysctl.start
#!/bin/sh
/sbin/sysctl -p
EOF
chmod +x /etc/local.d/sysctl.start
rc-update add local default

# Configure iptables
echo "Configuring iptables..."
## Cleanup
iptables-save | awk '/^[*]/ { print substr($1, 2) }' | xargs -I {} sh -c 'iptables -t {} -F && iptables -t {} -X'
## Default policies
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth1 -d "$ETH0_NETWORK" -j REJECT
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
### Port forwarding ###
# Router:8080 -> Maria_Prod:8080 (check marina/prod/dockers/swag/pod.sh)
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 8080 -j DNAT --to-destination "$MARINA_PROD_IP:8080"
# Router:4443 -> Maria_Prod:4443 (check marina/prod/dockers/swag/pod.sh)
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 4443 -j DNAT --to-destination "$MARINA_PROD_IP:4443"
iptables -A FORWARD -p tcp -d "$MARINA_PROD_IP" --dport 4443 -j ACCEPT
#######################
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
dhcp-host=$BHULK_MAC,$BHULK_IP
dhcp-host=$MARINA_PROD_MAC,$MARINA_PROD_IP
# dhcp-host=$MARINA_STAGING_MAC,$MARINA_STAGING_IP
# dhcp-host=$MARINA_RANDOM_MAC,$MARINA_RANDOM_IP
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
fi

echo "Reboot cancelled. You can manually reboot the system when ready."
