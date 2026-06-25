#!/bin/bash
echo "=== Блок 9: Настройка файрвола и проброса портов ==="

SAMBA_IP="192.168.10.51"
SAMBA_VNET="vnet69"

# Подключаем интерфейс Samba-сервера к мосту (если отвалился)
if ip link show $SAMBA_VNET &>/dev/null; then
    sudo ip link set $SAMBA_VNET master br-lan-a 2>/dev/null || true
fi

# Правила на KVM-роутере
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.17.10 \
  "sudo iptables -F FORWARD; \
   sudo iptables -I FORWARD 1 -m state --state RELATED,ESTABLISHED -j ACCEPT; \
   sudo iptables -I FORWARD 2 -i enp1s0 -o enp3s0 -p tcp --dport 445 -d $SAMBA_IP -j ACCEPT; \
   sudo iptables -A FORWARD -s 192.168.10.0/24 -d 192.168.20.0/24 -j ACCEPT; \
   sudo iptables -A FORWARD -s 192.168.20.0/24 -d 192.168.10.0/24 -j ACCEPT; \
   sudo iptables -A FORWARD -i enp3s0 -o enp1s0 -j ACCEPT; \
   sudo iptables -A FORWARD -i enp2s0 -o enp1s0 -j ACCEPT; \
   sudo iptables -A FORWARD -i lo -j ACCEPT; \
   sudo iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 445 -j DNAT --to-destination $SAMBA_IP:445; \
   sudo iptables -P FORWARD DROP"

echo "Проверка доступа к Samba:"
echo "  Из LAN-A:"
echo "quit" | sudo ip netns exec pc-a smbclient //$SAMBA_IP/share -N 2>/dev/null && echo "    OK" || echo "    НЕТ"
echo "  Из LAN-B:"
echo "quit" | sudo ip netns exec pc-b smbclient //$SAMBA_IP/share -N 2>/dev/null && echo "    OK" || echo "    НЕТ"
echo "  Из WAN (через проброс порта):"
echo "quit" | smbclient //192.168.17.10/share -N 2>/dev/null && echo "    OK" || echo "    НЕТ"
echo "OK"
