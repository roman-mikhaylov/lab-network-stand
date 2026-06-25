#!/bin/bash
# Автонастройка KVM-роутера при загрузке
sudo systemctl restart isc-dhcp-server
sudo systemctl restart frr
sudo iptables -t nat -A POSTROUTING -o enp1s0 -j MASQUERADE 2>/dev/null
sudo iptables -A FORWARD -i enp3s0 -o enp1s0 -j ACCEPT 2>/dev/null
sudo iptables -A FORWARD -i enp2s0 -o enp1s0 -j ACCEPT 2>/dev/null
sudo sysctl -w net.ipv4.ip_forward=1
echo "VM setup done"
