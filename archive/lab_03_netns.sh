#!/bin/bash
echo "=== Блок 3: Netns и DNS ==="
sudo ip netns add pc-a 2>/dev/null || true
sudo ip netns add pc-b 2>/dev/null || true
sudo ip netns add r2 2>/dev/null || true
sudo mkdir -p /etc/netns/pc-a /etc/netns/pc-b /etc/netns/r2
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-a/resolv.conf >/dev/null
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/pc-b/resolv.conf >/dev/null
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/r2/resolv.conf >/dev/null
echo "OK"
