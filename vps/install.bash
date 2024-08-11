#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PASSWORD_FILE="/root/user_passwords.txt"
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

######## Utility functions ########
create_user() {
    local USR_HOME
    if [ -z "$1" ]; then
        echo "No username provided."
        exit 1
    fi
    useradd -m "$1"
    USR_HOME="$(eval echo ~"$1")"

    ## SSH
    mkdir -p "$USR_HOME/.ssh"
    for pub in "$PWD"/authorized_keys/"$1"/*.pub; do
        cat "$pub" >> "$USR_HOME/.ssh/authorized_keys"
    done
    chmod -R 600 "$USR_HOME/.ssh/authorized_keys"
    chown -R "$1:$1" "$USR_HOME"

    echo "User $1 created."
}

create_sudo_user() {
    local PASSWD HASHED_PASSWD
    create_user "$1"
    usermod -aG wheel "$1"

    PASSWD=$(openssl rand -base64 32)
    HASHED_PASSWD=$(openssl passwd -6 "$PASSWD")
    echo "$1:$HASHED_PASSWD" | chpasswd -e

    echo "User $1 (sudo) created with password: $PASSWD" >> "$PASSWORD_FILE"
}
###################################

################################ Update System ################################
echo "--- Updating repositories and installing packages... ---"
curl -s https://install.crowdsec.net | sh
dnf copr enable -y atim/bottom
dnf install -y epel-release
dnf install -y podman firewalld rsync crowdsec crowdsec-firewall-bouncer-iptables bottom
dnf upgrade -y
############################## Additional Users ###############################
echo "--- Creating additional users... ---"
create_sudo_user "vic1707"
create_user "bistro-tech"
################################## SSH Setup ##################################
echo "--- Hardening SSH... ---"
RDM_SSH_PORT=$(shuf -n 1 -i 10000-65500)
sed -i "s/PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
sed -i "s/#Port 22/Port $RDM_SSH_PORT/g" /etc/ssh/sshd_config
sed -i "s/#AddressFamily any/AddressFamily inet/g" /etc/ssh/sshd_config
sed -i "s/#PermitEmptyPasswords no/PermitEmptyPasswords no/g" /etc/ssh/sshd_config
sed -i "s/#LogLevel INFO/LogLevel VERBOSE/g" /etc/ssh/sshd_config
sed -i "s/#MaxAuthTries 6/MaxAuthTries 3/g" /etc/ssh/sshd_config
sed -i "s/#MaxSessions 10/MaxSessions 2/g" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
sed -i "s/#MaxStartups 10:30:100/MaxStartups 3:50:3/g" /etc/ssh/sshd_config
sed -i "s/#TCPKeepAlive yes/TCPKeepAlive yes/g" /etc/ssh/sshd_config
sed -i "s/#LoginGraceTime 2m/LoginGraceTime 0/g" /etc/ssh/sshd_config
systemctl restart sshd
############################### Firewall Setup ################################
echo "--- Configuring firewall... ---"
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --remove-service=ssh
firewall-cmd --permanent --add-port="$RDM_SSH_PORT/tcp"
systemctl restart firewalld
############################### Crowdsec Setup ################################
echo "--- Configuring Crowdsec... ---"
BOUNCER_API_KEY=$(cscli bouncers add firewall -o raw)
sed -i "s/api_key: <API_KEY>/api_key: $BOUNCER_API_KEY/g" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
systemctl enable crowdsec.service
systemctl start crowdsec.service
############################# Additional Settings #############################
echo "--- Configuring additional settings... ---"
## Ask for password when invoking sudo
echo "--- Configuring sudo... ---"
rm -f /etc/sudoers.d/90-cloud-init-users
sed -i 's/NOPASSWD: //g' /etc/sudoers
## Disable IPv6
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf

echo "
    New SSH port: $RDM_SSH_PORT
    Don't forget to:
    - read $PASSWORD_FILE.
    - enroll crowdsec: 'cscli console enroll -e context <key>'    
"
