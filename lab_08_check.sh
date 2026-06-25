#!/bin/bash
echo "=== Блок 8: Проверка связи ==="
PC_B_IP=$(sudo ip netns exec pc-b ip addr show pc-b-eth | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
if [ -z "$PC_B_IP" ]; then
    echo "PC-B не получил IP. Запустите DHCP на Router2:"
    echo "  sudo ip netns exec r2 nohup dhcpd -4 -f -d r2-eth1 &>/dev/null &"
    echo "  sudo ip netns exec pc-b dhclient pc-b-eth"
    exit 1
fi
echo "PC-B IP: $PC_B_IP"
sudo ip netns exec pc-a ping -c 2 -W 2 $PC_B_IP && echo "PC-A -> PC-B: OK" || echo "PC-A -> PC-B: НЕТ"
sudo ip netns exec pc-a ping -c 2 -W 2 8.8.8.8 && echo "Интернет: OK" || echo "Интернет: НЕТ"
