#!/bin/bash
echo "============================================"
echo " ШАГ 06: Настройка KVM-роутера (NAT, OSPF, DHCP)"
echo "============================================"

sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.17.10 <<'REMOTE'
sudo apt update && sudo apt install -y frr isc-dhcp-server iptables-persistent 2>/dev/null

# Включаем OSPF
sudo sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
sudo systemctl restart frr
sudo vtysh -c "conf t" -c "router ospf" -c "router-id 192.168.17.10" -c "network 10.10.12.0/30 area 0" -c "network 192.168.10.0/24 area 0"

# DHCP для LAN-A
sudo tee /etc/dhcp/dhcpd.conf <<'DHCP'
default-lease-time 600;
max-lease-time 7200;
option subnet-mask 255.255.255.0;
option broadcast-address 192.168.10.255;
option routers 192.168.10.1;
option domain-name-servers 8.8.8.8, 8.8.4.4;
subnet 192.168.10.0 netmask 255.255.255.0 {
  range 192.168.10.50 192.168.10.100;
}
DHCP
sudo sed -i 's/INTERFACESv4=""/INTERFACESv4="enp3s0"/' /etc/default/isc-dhcp-server
sudo systemctl restart isc-dhcp-server

# NAT и форвардинг
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o enp1s0 -j MASQUERADE
sudo iptables -A FORWARD -i enp3s0 -o enp1s0 -j ACCEPT
sudo iptables -A FORWARD -i enp2s0 -o enp1s0 -j ACCEPT
sudo iptables -A FORWARD -i enp1s0 -o enp3s0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i enp1s0 -o enp2s0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i enp2s0 -o enp3s0 -j ACCEPT
sudo iptables -A FORWARD -i enp3s0 -o enp2s0 -j ACCEPT

echo "KVM-ROUTER-OK"
REMOTE

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  KVM-роутер настроен:"
echo "    OSPF: router-id 192.168.17.10, сети 10.10.12.0/30 и 192.168.10.0/24"
echo "    DHCP: пул 192.168.10.50-100, шлюз 192.168.10.1"
echo "    NAT: включён (MASQUERADE на enp1s0)"
echo "    Форвардинг: разрешён между всеми интерфейсами"
echo ""
echo "  Проверка:"
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.17.10 "sudo systemctl status isc-dhcp-server | grep Active | awk '{print \$2,\$3}'"
sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.17.10 "sudo vtysh -c 'show ip ospf neighbor'" 2>/dev/null | grep -q "Full" && echo "    OSPF: OK" || echo "    OSPF: ОШИБКА"
echo "OK"
