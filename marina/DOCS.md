Steps done for each backup on proxmox:

### Backup `post install`

1. Create a new VM and do basic setup (name, memory, cpu, disk, network, etc)

---

### Backup `SSH key, git repo, PASSWD`

1. Install `git`, ssh keys, and change password
   - **ON LOCAL COMPUTER**: `ssh-copy-id -i ~/.ssh/marina-prod.pub marina@10.0.0.3`
   - `sudo dnf update -y`
   - `sudo dnf install -y git`
   - `git clone https://github.com/vic1707/homelab-config`
   - `sudo passwd`

---

### Backup `SSH Hardening`

1. run the `ssh.sh` script

---

### Backup `Basic installation & nvidia drivers`

1. run the `install.sh` script
2. reboot
   #### on prod only
   3.a. run the `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` command
   3.b. check everything is ok with `nvidia-ctk cdi list`
   3.c. run `podman run --privileged --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi` and check that the output is ok

---

HAVE fun!
