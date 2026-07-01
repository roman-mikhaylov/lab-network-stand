#!/bin/bash
echo "=== Блок 1: Очистка ==="
sudo pkill -9 -f dhcpd 2>/dev/null || true
sudo pkill -f dhclient 2>/dev/null || true
sudo pkill -f zebra 2>/dev/null || true
sudo pkill -f ospfd 2>/dev/null || true
sudo ip netns del pc-a 2>/dev/null || true
sudo ip netns del pc-b 2>/dev/null || true
sudo ip netns del r2 2>/dev/null || true
sudo ip link del pc-a-eth 2>/dev/null || true
sudo ip link del pc-b-eth 2>/dev/null || true
sudo ip link del r2-eth0 2>/dev/null || true
sudo ip link del r2-eth1 2>/dev/null || true
sudo ip link del lan-a-port1 2>/dev/null || true
sudo ip link del lan-a-port2 2>/dev/null || true
sudo ip link del lan-b-port1 2>/dev/null || true
sudo ip link del lan-b-port2 2>/dev/null || true
sudo ip link del transit-r2 2>/dev/null || true
sudo ip link del br-lan-a 2>/dev/null || true
sudo ip link del br-lan-b 2>/dev/null || true
sudo ip link del br-wan 2>/dev/null || true
sudo ip link del br-transit 2>/dev/null || true
sudo virsh destroy kvm-router 2>/dev/null || true
echo "OK"
