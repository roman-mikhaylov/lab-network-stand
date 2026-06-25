#!/bin/bash
echo "=== Блок 5: Router2 (netns) ==="

# Создаём veth-пары
sudo ip link add r2-eth1 type veth peer name lan-b-port2 2>/dev/null || true
sudo ip link set r2-eth1 netns r2 2>/dev/null || true
sudo ip link set lan-b-port2 master br-lan-b 2>/dev/null || true
sudo ip link set lan-b-port2 up

sudo ip link add r2-eth0 type veth peer name transit-r2 2>/dev/null || true
sudo ip link set r2-eth0 netns r2 2>/dev/null || true
sudo ip link set transit-r2 master br-transit 2>/dev/null || true
sudo ip link set transit-r2 up

# Настройка интерфейсов внутри r2
sudo ip netns exec r2 ip link set lo up
sudo ip netns exec r2 ip link set r2-eth1 up
sudo ip netns exec r2 ip link set r2-eth0 up
sudo ip netns exec r2 ip addr add 192.168.20.1/24 dev r2-eth1 2>/dev/null || true
sudo ip netns exec r2 ip addr add 10.10.12.2/30 dev r2-eth0 2>/dev/null || true
sudo ip netns exec r2 ip route add default via 10.10.12.1 2>/dev/null || true

# FRR
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

# DHCP
sudo pkill -f "dhcpd.*r2-eth1" 2>/dev/null || true
sleep 1
sudo ip netns exec r2 rm -f /var/lib/dhcp/dhcpd.leases
sudo ip netns exec r2 touch /var/lib/dhcp/dhcpd.leases
sudo ip netns exec r2 chmod 777 /var/lib/dhcp/dhcpd.leases
sudo ip netns exec r2 nohup dhcpd -4 -f -d r2-eth1 &>/dev/null &
sleep 2

echo "OK"
