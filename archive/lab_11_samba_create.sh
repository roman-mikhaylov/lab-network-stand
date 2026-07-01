#!/bin/bash
echo "=== Блок 11: Создание файлового сервера Samba ==="

# Проверяем, существует ли уже ВМ
if sudo virsh list --all --name | grep -q samba-server; then
    echo "  ВМ samba-server уже существует."
    if ! sudo virsh list --name | grep -q samba-server; then
        echo "  Запуск существующей ВМ..."
        sudo virsh start samba-server
        sleep 40
    fi
else
    echo "  Создание диска..."
    sudo qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/samba-server.qcow2 5G
    sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/samba-server.qcow2

    echo "  Создание cloud‑init ISO..."
    cat > /tmp/samba-init.yml <<'YML'
#cloud-config
hostname: samba-server
ssh_pwauth: true
chpasswd:
  list: |
    ubuntu:123
  expire: false
packages:
  - samba
runcmd:
  - mkdir -p /srv/samba/share
  - chmod 777 /srv/samba/share
  - echo -e "[share]\n  path = /srv/samba/share\n  browseable = yes\n  read only = no\n  guest ok = yes" >> /etc/samba/smb.conf
  - systemctl restart smbd
YML
    sudo cloud-localds /var/lib/libvirt/images/samba-seed.img /tmp/samba-init.yml
    sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/samba-seed.img

    echo "  Запуск ВМ..."
    sudo virt-install \
      --name samba-server \
      --memory 512 \
      --vcpus 1 \
      --disk path=/var/lib/libvirt/images/samba-server.qcow2,format=qcow2 \
      --disk path=/var/lib/libvirt/images/samba-seed.img,format=raw \
      --import \
      --osinfo ubuntu22.04 \
      --network bridge=br-lan-a,model=virtio \
      --graphics none \
      --console pty,target_type=serial \
      --noautoconsole
fi

echo "  Ожидание загрузки (50 секунд)..."
sleep 50

# Получаем IP Samba-сервера (DHCP от KVM‑роутера)
SAMBA_IP=$(sudo virsh net-dhcp-leases default 2>/dev/null | grep samba | awk '{print $5}' | cut -d/ -f1)
if [ -z "$SAMBA_IP" ]; then
    # Пробуем найти через арпинг
    SAMBA_IP=$(ip neigh | grep -i "52:54:00:5f:44:b1" | awk '{print $1}' 2>/dev/null)
fi
[ -z "$SAMBA_IP" ] && SAMBA_IP="192.168.10.51"  # fallback

echo "  Samba-сервер IP: $SAMBA_IP"
ping -c 1 -W 2 $SAMBA_IP >/dev/null 2>&1 && echo "  Samba-сервер доступен: OK" || echo "  Samba-сервер недоступен: проверьте"
echo "OK"
