#!/bin/bash
echo "============================================"
echo " ШАГ 09: Создание и настройка Org-server"
echo "============================================"

# Удаляем старый, если есть
echo "  Очистка старого org-server..."
sudo virsh destroy org-server 2>/dev/null || true
sudo virsh undefine org-server --remove-all-storage 2>/dev/null || true

# Маршрут на хосте для доступа к LAN-A
sudo ip route add 192.168.10.0/24 dev br-lan-a 2>/dev/null || true

# Создаём диск
echo "  Создание диска..."
sudo qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/org-server.qcow2 10G
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/org-server.qcow2

# Cloud-init
echo "  Создание cloud-init..."
cat > /tmp/org-init.yml <<'YML'
#cloud-config
hostname: org-server
ssh_pwauth: true
chpasswd:
  list: |
    ubuntu:123
  expire: false
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.10.10/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
YML
sudo cloud-localds /var/lib/libvirt/images/org-server-seed.img /tmp/org-init.yml
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/org-server-seed.img

# Запуск ВМ
echo "  Запуск ВМ..."
sudo virt-install \
  --name org-server \
  --memory 1024 \
  --vcpus 1 \
  --disk path=/var/lib/libvirt/images/org-server.qcow2,format=qcow2 \
  --disk path=/var/lib/libvirt/images/org-server-seed.img,format=raw \
  --import \
  --osinfo ubuntu22.04 \
  --network bridge=br-lan-a,model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --noautoconsole

echo "  Ожидание загрузки (50 секунд)..."
sleep 50

# Проверка доступности
echo ""
echo "РЕЗУЛЬТАТ:"
ping -c 2 -W 2 192.168.10.10 >/dev/null 2>&1 && echo "  org-server доступен (192.168.10.10)" || echo "  org-server недоступен"
echo "OK"
