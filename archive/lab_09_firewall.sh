#!/bin/bash
echo "=== Блок 9: Настройка файрвола и проброса портов ==="

# Применяем правила через консоль KVM-роутера
sudo virsh console kvm-router --force <<'CMDS' 2>/dev/null
ubuntu
123
sudo iptables -F FORWARD
sudo iptables -I FORWARD 1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I FORWARD 2 -i enp1s0 -o enp3s0 -p tcp --dport 445 -d 192.168.10.51 -j ACCEPT
sudo iptables -A FORWARD -s 192.168.10.0/24 -d 192.168.20.0/24 -j ACCEPT
sudo iptables -A FORWARD -s 192.168.20.0/24 -d 192.168.10.0/24 -j ACCEPT
sudo iptables -A FORWARD -i enp3s0 -o enp1s0 -j ACCEPT
sudo iptables -A FORWARD -i enp2s0 -o enp1s0 -j ACCEPT
sudo iptables -A FORWARD -i lo -j ACCEPT
sudo iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 445 -j DNAT --to-destination 192.168.10.51:445
sudo iptables -P FORWARD DROP
exit
CMDS

sleep 2

echo "Проверка доступа к Samba:"
echo "  Из LAN-A:"
echo "quit" | sudo ip netns exec pc-a smbclient //192.168.10.51/share -N 2>/dev/null && echo "    OK" || echo "    НЕТ"
echo "  Из LAN-B:"
echo "quit" | sudo ip netns exec pc-b smbclient //192.168.10.51/share -N 2>/dev/null && echo "    OK" || echo "    НЕТ"
echo "  Из WAN (через проброс порта):"
echo "quit" | smbclient //192.168.17.10/share -N 2>/dev/null && echo "    OK" || echo "    НЕТ"
echo "OK"
