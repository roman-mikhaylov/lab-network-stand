#!/bin/bash
set -e

echo "============================================"
echo "  Запуск учебного сетевого стенда"
echo "============================================"

# 1. Очистка старых интерфейсов
echo ">>> Очистка..."
sudo ip link del pc-a-eth 2>/dev/null || true
sudo ip link del pc-b-eth 2>/dev/null || true
sudo ip link del r2-eth0 2>/dev/null || true
sudo ip link del r2-eth1 2>/dev/null || true
sudo ip link del lan-a-port1 2>/dev/null || true
sudo ip link del lan-a-port2 2>/dev/null || true
sudo ip link del lan-b-port1 2>/dev/null || true
sudo ip link del lan-b-port2 2>/dev/null || true
sudo ip link del transit-r2 2>/dev/null || true

# 2. Мосты
echo ">>> Создание bridge..."
sudo ip link add br-lan-a type bridge 2>/dev/null || true
sudo ip link add br-lan-b type bridge 2>/dev/null || true
sudo ip link add br-wan type bridge 2>/dev/null || true
sudo ip link add br-transit type bridge 2>/dev/null || true
sudo ip link set br-lan-a up
sudo ip link set br-lan-b up
sudo ip link set br-wan up
sudo ip link set br-transit up
sudo ip addr add 192.168.17.1/24 dev br-wan 2>/dev/null || true

# 3. NAT на хосте
echo ">>> NAT на хосте..."
sudo iptables -t nat -C POSTROUTING -s 192.168.17.0/24 ! -d 192.168.17.0/24 -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -s 192.168.17.0/24 ! -d 192.168.17.0/24 -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1

# 4. Netns
echo ">>> Создание netns..."
sudo ip netns add pc-a 2>/dev/null || true
sudo ip netns add pc-b 2>/dev/null || true
sudo ip netns add r2 2>/dev/null || true

# 5. DNS
echo ">>> DNS..."
sudo mkdir -p /etc/netns/pc-a /etc/netns/pc-b /etc/netns/r2
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-a/resolv.conf >/dev/null
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-b/resolv.conf >/dev/null
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/r2/resolv.conf >/dev/null

# 6. PC-A
echo ">>> PC-A..."
sudo ip link add pc-a-eth type veth peer name lan-a-port1
sudo ip link set pc-a-eth netns pc-a
sudo ip link set lan-a-port1 master br-lan-a
sudo ip link set lan-a-port1 up
sudo ip netns exec pc-a ip link set lo up
sudo ip netns exec pc-a ip link set pc-a-eth up

# 7. PC-B
echo ">>> PC-B..."
sudo ip link add pc-b-eth type veth peer name lan-b-port1
sudo ip link set pc-b-eth netns pc-b
sudo ip link set lan-b-port1 master br-lan-b
sudo ip link set lan-b-port1 up
sudo ip netns exec pc-b ip link set lo up
sudo ip netns exec pc-b ip link set pc-b-eth up

# 8. Router2
echo ">>> Router2..."
sudo ip link add r2-eth1 type veth peer name lan-b-port2
sudo ip link set r2-eth1 netns r2
sudo ip link set lan-b-port2 master br-lan-b
sudo ip link set lan-b-port2 up
sudo ip link add r2-eth0 type veth peer name transit-r2
sudo ip link set r2-eth0 netns r2
sudo ip link set transit-r2 master br-transit
sudo ip link set transit-r2 up
sudo ip netns exec r2 ip link set lo up
sudo ip netns exec r2 ip link set r2-eth1 up
sudo ip netns exec r2 ip link set r2-eth0 up
sudo ip netns exec r2 ip addr add 192.168.20.1/24 dev r2-eth1 2>/dev/null || true
sudo ip netns exec r2 ip addr add 10.10.12.2/30 dev r2-eth0 2>/dev/null || true
sudo ip netns exec r2 ip route add default via 10.10.12.1 2>/dev/null || true

# 9. FRR на Router2
echo ">>> FRR на Router2..."
sudo pkill -f "zebra.*frr-r2" 2>/dev/null || true
sudo pkill -f "ospfd.*frr-r2" 2>/dev/null || true
sudo mkdir -p /var/run/frr-r2
sudo chown frr:frr /var/run/frr-r2
sleep 1
sudo ip netns exec r2 /usr/lib/frr/zebra \
  -f /etc/frr-r2/zebra.conf \
  -i /var/run/frr-r2/zebra.pid \
  -z /var/run/frr-r2/zebra.sock \
  -u frr -g frr -N r2 &
sleep 1
sudo ip netns exec r2 /usr/lib/frr/ospfd \
  -f /etc/frr-r2/ospfd.conf \
  -i /var/run/frr-r2/ospfd.pid \
  -z /var/run/frr-r2/zebra.sock \
  -u frr -g frr -N r2 &

# 10. DHCP на Router2
echo ">>> DHCP на Router2..."
sudo pkill -f "dhcpd.*r2-eth1" 2>/dev/null || true
sleep 1
sudo ip netns exec r2 rm -f /var/lib/dhcp/dhcpd.leases
sudo ip netns exec r2 touch /var/lib/dhcp/dhcpd.leases
sudo ip netns exec r2 chmod 777 /var/lib/dhcp/dhcpd.leases
sudo ip netns exec r2 nohup dhcpd -4 -f -d r2-eth1 &>/dev/null &
sleep 2

# 11. KVM-роутер
echo ">>> KVM-роутер..."
if ! sudo virsh list --name | grep -q kvm-router; then
    sudo virsh start kvm-router
    echo "  Ожидание загрузки (50 секунд)..."
    sleep 50
fi

# 12. DHCP для клиентов
echo ">>> DHCP для клиентов..."
sudo pkill -f "dhclient" 2>/dev/null || true
sudo ip netns exec pc-a dhclient pc-a-eth 2>/dev/null &
sudo ip netns exec pc-b dhclient pc-b-eth 2>/dev/null &
sleep 8

# 13. Маршруты
echo ">>> Маршруты..."
sudo ip netns exec pc-a ip route add default via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-a ip route add 192.168.20.0/24 via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add default via 192.168.20.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add 192.168.10.0/24 via 192.168.20.1 2>/dev/null || true

# 14. Проверка
echo ""
echo "============================================"
echo "  Стенд запущен!"
echo "============================================"
PC_B_IP=$(sudo ip netns exec pc-b ip addr show pc-b-eth | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
echo "  PC-B IP: $PC_B_IP"
echo ""
echo "  PC-A -> PC-B:"
sudo ip netns exec pc-a ping -c 2 -W 2 $PC_B_IP && echo "  OK" || echo "  (не работает)"
echo "  PC-A -> интернет:"
sudo ip netns exec pc-a ping -c 2 -W 2 8.8.8.8 && echo "  OK" || echo "  (не работает)"
echo ""
echo "Консоль KVM-роутера:  sudo virsh console kvm-router"
echo "Консоль Router2:      sudo ip netns exec r2 bash"
echo "Консоль PC-A:         sudo ip netns exec pc-a bash"
echo "Консоль PC-B:         sudo ip netns exec pc-b bash"
