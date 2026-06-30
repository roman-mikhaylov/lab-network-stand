#!/bin/bash
echo "============================================"
echo " ШАГ 12: Fail2ban (защита от перебора паролей)"
echo "============================================"

sshpass -p "123" ssh -o StrictHostKeyChecking=no ubuntu@192.168.10.10 <<'EOF'
echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf
sudo apt update && sudo apt install -y fail2ban 2>/dev/null

sudo tee /etc/fail2ban/jail.local <<'F2B'
[sshd]
enabled = true
port = 2222
maxretry = 3
bantime = 3600
findtime = 600
F2B

sudo systemctl restart fail2ban
sudo systemctl enable fail2ban
echo "FAIL2BAN-OK"
EOF

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  Fail2ban установлен и настроен"
echo "  Порт: 2222"
echo "  Макс. попыток: 3"
echo "  Бан на 1 час"
echo "OK"
