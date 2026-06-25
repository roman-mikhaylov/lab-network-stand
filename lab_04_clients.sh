#!/bin/bash
echo "=== Блок 4: Клиенты PC-A и PC-B ==="
sudo ip link add pc-a-eth type veth peer name lan-a-port1 2>/dev/null || true
sudo ip link set pc-a-eth netns pc-a 2>/dev/null || true
sudo ip link set lan-a-port1 master br-lan-a 2>/dev/null || true
sudo ip link set lan-a-port1 up
sudo ip netns exec pc-a ip link set lo up
sudo ip netns exec pc-a ip link set pc-a-eth up

sudo ip link add pc-b-eth type veth peer name lan-b-port1 2>/dev/null || true
sudo ip link set pc-b-eth netns pc-b 2>/dev/null || true
sudo ip link set lan-b-port1 master br-lan-b 2>/dev/null || true
sudo ip link set lan-b-port1 up
sudo ip netns exec pc-b ip link set lo up
sudo ip netns exec pc-b ip link set pc-b-eth up
echo "OK"
