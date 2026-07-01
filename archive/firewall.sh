#!/bin/bash
echo "=== Настройка файрвола на KVM-роутере ==="

ssh ubuntu@192.168.17.10 << 'EOF'
sudo iptables -F FORWARD
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -s 192.168.10.0/24 -d 192.168.20.0/24 -j ACCEPT
sudo iptables -A FORWARD -s 192.168.20.0/24 -d 192.168.10.0/24 -j ACCEPT
sudo iptables -A FORWARD -i enp3s0 -o enp1s0 -j ACCEPT
sudo iptables -A FORWARD -i enp2s0 -o enp1s0 -j ACCEPT
sudo iptables -A FORWARD -i lo -j ACCEPT
sudo iptables -P FORWARD DROP
echo "Правила применены:"
sudo iptables -L FORWARD -v
EOF

echo "=== Файрвол настроен ==="
