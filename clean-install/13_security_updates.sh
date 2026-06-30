#!/bin/bash
echo "============================================"
echo " ШАГ 13: Автоматические обновления безопасности"
echo "============================================"

sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'EOF'
echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf
sudo apt update && sudo apt install -y unattended-upgrades 2>/dev/null

sudo tee /etc/apt/apt.conf.d/20auto-upgrades <<'APT'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
APT
sudo systemctl restart unattended-upgrades
echo "UPDATES-OK"
EOF

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  Автообновления безопасности включены"
echo "  Проверка: ежедневно"
echo "  Очистка кеша: раз в 7 дней"
echo "OK"

