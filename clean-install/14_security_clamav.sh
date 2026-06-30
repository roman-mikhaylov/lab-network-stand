#!/bin/bash
echo "============================================"
echo " ШАГ 14: ClamAV (антивирус)"
echo "============================================"

sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'EOF'
echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf
sudo apt update && sudo apt install -y clamav clamav-daemon 2>/dev/null
sudo freshclam 2>/dev/null
sudo systemctl restart clamav-daemon 2>/dev/null

# Ежедневное сканирование папок Samba через cron
echo "0 3 * * * clamscan -r /srv/samba --log=/var/log/clamav/scan.log" | sudo crontab -
echo "CLAMAV-OK"
EOF

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  ClamAV установлен"
echo "  Базы обновлены"
echo "  Ежедневное сканирование /srv/samba в 3:00"
echo "OK"
