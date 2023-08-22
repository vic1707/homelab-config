examples

```bash
# HTTP TCP port 80
iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j DNAT --to 10.1.0.50:80
iptables -A FORWARD -p tcp -d 10.1.0.50 --dport 80 -j ACCEPT

# HTTPS TCP port 443
iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 443 -j DNAT --to 10.1.0.50:443
iptables -A FORWARD -p tcp -d 10.1.0.50 --dport 443 -j ACCEPT
```

source: https://www.reddit.com/r/Proxmox/comments/vdi7ea/using_an_lxc_container_as_a_router/
