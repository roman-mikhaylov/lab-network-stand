#!/bin/bash
set -e

echo "=== Создание bridge ==="
sudo ip link add br-lan-a type bridge 2>/dev/null || true
sudo ip link add br-lan-b type bridge 2>/dev/null || true
sudo ip link add br-wan type bridge 2>/dev/null || true
sudo ip link add br-transit type bridge 2>/dev/null || true
sudo ip link set br-lan-a up
sudo ip link set br-lan-b up
sudo ip link set br-wan up
sudo ip link set br-transit up
sudo ip addr add 192.168.17.1/24 dev br-wan 2>/dev/null || true

echo "=== Создание network namespaces ==="
sudo ip netns add pc-a 2>/dev/null || true
sudo ip netns add pc-b 2>/dev/null || true
sudo ip netns add r2 2>/dev/null || true

echo "=== PC-A -> LAN-A ==="
sudo ip link add pc-a-eth type veth peer name lan-a-port1 2>/dev/null || true
sudo ip link set pc-a-eth netns pc-a 2>/dev/null || true
sudo ip link set lan-a-port1 master br-lan-a 2>/dev/null || true
sudo ip link set lan-a-port1 up
sudo ip netns exec pc-a ip link set lo up
sudo ip netns exec pc-a ip link set pc-a-eth up
# DHCP на PC-A
sudo ip netns exec pc-a dhclient -v pc-a-eth 2>/dev/null &
sleep 2
sudo ip netns exec pc-a ip route add default via 192.168.10.1 2>/dev/null || true
sudo ip netns exec pc-a ip route add 192.168.20.0/24 via 192.168.10.1 2>/dev/null || true

echo "=== PC-B -> LAN-B ==="
sudo ip link add pc-b-eth type veth peer name lan-b-port1 2>/dev/null || true
sudo ip link set pc-b-eth netns pc-b 2>/dev/null || true
sudo ip link set lan-b-port1 master br-lan-b 2>/dev/null || true
sudo ip link set lan-b-port1 up
sudo ip netns exec pc-b ip link set lo up
sudo ip netns exec pc-b ip link set pc-b-eth up
# DHCP на PC-B
sudo ip netns exec pc-b dhclient -v pc-b-eth 2>/dev/null &
sleep 2
sudo ip netns exec pc-b ip route add default via 192.168.20.1 2>/dev/null || true
sudo ip netns exec pc-b ip route add 192.168.10.0/24 via 192.168.20.1 2>/dev/null || true

echo "=== Router2 -> LAN-B + Transit ==="
sudo ip link add r2-eth1 type veth peer name lan-b-port2 2>/dev/null || true
sudo ip link set r2-eth1 netns r2 2>/dev/null || true
sudo ip link set lan-b-port2 master br-lan-b 2>/dev/null || true
sudo ip link set lan-b-port2 up
sudo ip link add r2-eth0 type veth peer name transit-r2 2>/dev/null || true
sudo ip link set r2-eth0 netns r2 2>/dev/null || true
sudo ip link set transit-r2 master br-transit 2>/dev/null || true
sudo ip link set transit-r2 up
sudo ip netns exec r2 ip link set lo up
sudo ip netns exec r2 ip link set r2-eth1 up
sudo ip netns exec r2 ip link set r2-eth0 up
sudo ip netns exec r2 ip addr add 192.168.20.1/24 dev r2-eth1 2>/dev/null || true
sudo ip netns exec r2 ip addr add 10.10.12.2/30 dev r2-eth0 2>/dev/null || true
sudo ip netns exec r2 ip route add default via 10.10.12.1 2>/dev/null || true

echo "=== Запуск FRR на Router2 ==="
sudo mkdir -p /var/run/frr-r2
sudo chown frr:frr /var/run/frr-r2
sudo ip netns exec r2 /usr/lib/frr/zebra -f /etc/frr-r2/zebra.conf -i /var/run/frr-r2/zebra.pid -z /var/run/frr-r2/zebra.sock -u frr -g frr -N r2 &
sleep 1
sudo ip netns exec r2 /usr/lib/frr/ospfd -f /etc/frr-r2/ospfd.conf -i /var/run/frr-r2/ospfd.pid -z /var/run/frr-r2/zebra.sock -u frr -g frr -N r2 &

echo "=== Запуск DHCP на Router2 ==="
sudo mkdir -p /etc/netns/r2
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/r2/resolv.conf
sudo ip netns exec r2 dhcpd -4 -f -d r2-eth1 &>/dev/null &

echo "=== DNS для PC-A ==="
sudo mkdir -p /etc/netns/pc-a
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-a/resolv.conf

echo "=== DNS для PC-B ==="
sudo mkdir -p /etc/netns/pc-b
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-b/resolv.conf

echo "=== Проверка KVM-роутера ==="
if ! sudo virsh list --name | grep -q kvm-router; then
    echo "Запуск kvm-router..."
    sudo virsh start kvm-router
fi

echo "=== Готово ==="
echo "Проверка:"
sudo ip netns exec pc-a ping -c 2 192.168.10.1
sudo ip netns exec pc-a ping -c 2 8.8.8.8
