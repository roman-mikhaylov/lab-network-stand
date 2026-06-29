#!/bin/bash
echo "=== Блок 13: Создание org-server ==="

echo "  Удаление старого org-server..."
sudo virsh destroy org-server 2>/dev/null || true
sudo virsh undefine org-server --remove-all-storage 2>/dev/null || true

echo "  Добавление маршрута на хосте..."
sudo ip route add 192.168.10.0/24 dev br-lan-a 2>/dev/null || true

echo "  Создание диска..."
sudo qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/org-server.qcow2 10G
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/org-server.qcow2

echo "  Создание cloud-init..."
cat > /tmp/org-init.yml <<'EOF'
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
      addresses:
        - 192.168.10.10/24
      gateway4: 192.168.10.1
      nameservers:
        addresses: [8.8.8.8]
EOF
sudo cloud-localds /var/lib/libvirt/images/org-server-seed.img /tmp/org-init.yml
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/org-server-seed.img

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

echo "  Ожидание загрузки (60 секунд)..."
sleep 60

echo "  Проверка доступности..."
ping -c 2 192.168.10.10 && echo "  org-server доступен" || echo "  org-server недоступен"
echo "OK"
