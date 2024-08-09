#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
GENERATED_FOLDER="$PWD/generated"

######## Utility functions ########
create_user() {
    if [ -z "$1" ]; then
        echo "No username provided."
        exit 1
    fi
    local USR_HOME PASSWD
    mkdir -p "$GENERATED_FOLDER/$1"

    PASSWD=$(openssl rand -base64 32)
    useradd -m -p "$PASSWD" "$1"
    USR_HOME="$(eval echo ~"$1")"

    echo "$PASSWD" > "$GENERATED_FOLDER/$1/passwd"
    echo "User $1 created."

    ## SSH
    mkdir -p "$USR_HOME/.ssh"
    ssh-keygen -t ed25519 -f "$GENERATED_FOLDER/$1/github" -N ""
    cat "$GENERATED_FOLDER/$1/github.pub" >> "$USR_HOME/.ssh/authorized_keys"
    chmod -R 600 "$USR_HOME/.ssh/authorized_keys"
    chown "$1:$1" "$USR_HOME/.ssh/authorized_keys"
}
###################################

################################ Update System ################################
echo "--- Updating repositories and installing packages... ---"
dnf copr enable -y atim/bottom
dnf install -y epel-release
dnf install -y podman firewalld rsync
dnf install -y bottom
dnf upgrade -y
############################### Additionnal Users #############################
echo "--- Creating additional users... ---"
create_user "vic1707"
create_user "bistro-tech"
################################## SSH Setup ##################################
echo "--- Hardening SSH... ---"
RDM_SSH_PORT=$(shuf -n 1 -i 10000-65500)
echo "$RDM_SSH_PORT" > "$PWD/generated/ssh-port"

sed -i "s/#Port 22/Port $RDM_SSH_PORT/g" /etc/ssh/sshd_config
sed -i "s/#AddressFamily any/AddressFamily inet/g" /etc/ssh/sshd_config
sed -i "s/#MaxAuthTries 6/MaxAuthTries 3/g" /etc/ssh/sshd_config
sed -i "s/#MaxSessions 10/MaxSessions 2/g" /etc/ssh/sshd_config
sed -i "s/#MaxStartups 10:30:100/MaxStartups 3:50:3/g" /etc/ssh/sshd_config
sed -i "s/#LogLevel INFO/LogLevel VERBOSE/g" /etc/ssh/sshd_config
sed -i "s/#TCPKeepAlive yes/TCPKeepAlive yes/g" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
sed -i "s/#PermitEmptyPasswords no/PermitEmptyPasswords no/g" /etc/ssh/sshd_config
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
sed -i "s/#LoginGraceTime 2m/LoginGraceTime 0/g" /etc/ssh/sshd_config
################################# Firewall Setup ##############################
echo "--- Configuring firewall... ---"
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --remove-service=ssh
firewall-cmd --permanent --add-port="$RDM_SSH_PORT/tcp"
############################# Additionnal Settings ############################
echo "--- Configuring additional settings... ---"
## Hostname
hostnamectl set-hostname "vic1707-VPS"
## Ask for password when invoking sudo
echo "--- Configuring sudo... ---"
rm -f /etc/sudoers.d/90-cloud-init-users
sed -i 's/NOPASSWD: //g' /etc/sudoers
## Disable IPv6
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf

# Reboot confirmation
echo "Configuration completed. Do you want to reboot now? (Y/N)"
read -r choice
if [ "$choice" = "Y" ] || [ "$choice" = "y" ]; then
    echo "Rebooting..."
    sleep 3
    reboot
fi

echo "Reboot cancelled. You can manually reboot the system when ready."
