#!/bin/sh

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

RDM_SSH_PORT=$(shuf -n 1 -i 10000-65500)

echo "
    #########################################
    #                                       #
    #          SSH PORT CHANGED !!          #
    #            NEW PORT: $RDM_SSH_PORT            #
    #                                       #
    #########################################
"

########## SSH Configuration ##########
# get ip of the interface that isn't loopback
MAIN_IP="$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)"

sed -i "s/#Port 22/Port $RDM_SSH_PORT/g" /etc/ssh/sshd_config
sed -i "s/#AddressFamily any/AddressFamily inet/g" /etc/ssh/sshd_config
sed -i "s/#MaxAuthTries 6/MaxAuthTries 3/g" /etc/ssh/sshd_config
sed -i "s/#MaxSessions 10/MaxSessions 2/g" /etc/ssh/sshd_config
sed -i "s/#MaxStartups 10:30:100/MaxStartups 3:50:3/g" /etc/ssh/sshd_config
sed -i "s/#ListenAddress 0.0.0.0/ListenAddress $MAIN_IP/g" /etc/ssh/sshd_config
sed -i "s/#LogLevel INFO/LogLevel VERBOSE/g" /etc/ssh/sshd_config
sed -i "s/#TCPKeepAlive yes/TCPKeepAlive yes/g" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
sed -i "s/#PermitEmptyPasswords no/PermitEmptyPasswords no/g" /etc/ssh/sshd_config
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config

systemctl restart sshd
########## FWD Configuration ##########
firewall-cmd --permanent --add-port="$RDM_SSH_PORT/tcp"
firewall-cmd --reload
