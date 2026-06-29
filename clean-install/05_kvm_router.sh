#!/bin/bash
echo "============================================"
echo " ШАГ 05: Создание и запуск KVM-роутера"
echo "============================================"

# Проверяем, существует ли уже ВМ
if sudo virsh list --all --name | grep -q kvm-router; then
    echo "  KVM-роутер уже существует, запускаем..."
    sudo virsh start kvm-router 2>/dev/null
else
    echo "  Создаём диск..."
    sudo qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/kvm-router.qcow2 10G 2>/dev/null
    sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/kvm-router.qcow2 2>/dev/null

    echo "  Создаём cloud-init..."
    cat > /tmp/kvm-init.yml <<'YML'
#cloud-config
hostname: kvm-router
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
        - 192.168.17.10/24
      routes:
        - to: default
          via: 192.168.17.1
    enp2s0:
      addresses:
        - 10.10.12.1/30
    enp3s0:
      addresses:
        - 192.168.10.1/24
YML
    sudo cloud-localds /var/lib/libvirt/images/kvm-router-seed.img /tmp/kvm-init.yml
    sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/kvm-router-seed.img

    echo "  Запуск ВМ..."
    sudo virt-install \
      --name kvm-router \
      --memory 1024 \
      --vcpus 1 \
      --disk path=/var/lib/libvirt/images/kvm-router.qcow2,format=qcow2 \
      --disk path=/var/lib/libvirt/images/kvm-router-seed.img,format=raw \
      --import \
      --osinfo ubuntu22.04 \
      --network bridge=br-wan,model=virtio \
      --network bridge=br-transit,model=virtio \
      --network bridge=br-lan-a,model=virtio \
      --graphics none \
      --console pty,target_type=serial \
      --noautoconsole
fi

echo "  Ожидание загрузки (60 секунд)..."
sleep 60

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  KVM-роутер запущен:"
echo "    enp1s0: 192.168.17.10/24 (WAN)"
echo "    enp2s0: 10.10.12.1/30 (Transit → Router2)"
echo "    enp3s0: 192.168.10.1/24 (LAN-A, шлюз для PC-A)"
echo ""
echo "  Проверка доступности:"
ping -c 1 -W 2 192.168.17.10 >/dev/null 2>&1 && echo "    192.168.17.10: доступен" || echo "    192.168.17.10: недоступен"
ping -c 1 -W 2 192.168.10.1 >/dev/null 2>&1 && echo "    192.168.10.1: доступен" || echo "    192.168.10.1: недоступен"
echo "OK"
