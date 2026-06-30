#!/bin/bash
echo "============================================"
echo " ШАГ 15: HTTPS (самоподписанный сертификат)"
echo "============================================"

sshpass -p "123" ssh -o StrictHostKeyChecking=no -p 2222 ubuntu@192.168.10.10 <<'EOF'
# Создать самоподписанный сертификат
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/org-server.key \
    -out /etc/ssl/certs/org-server.crt \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Org/CN=org-server.local"

# Настроить Nginx для HTTPS
sudo tee /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name _;
    root /var/www/html;
    index index.html;

    ssl_certificate /etc/ssl/certs/org-server.crt;
    ssl_certificate_key /etc/ssl/private/org-server.key;

    location /admin {
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        alias /var/www/html/admin/;
        try_files $uri $uri/ /admin/index.html;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

# Открыть порт 443
sudo ufw allow 443/tcp
sudo systemctl restart nginx
echo "HTTPS-OK"
EOF

echo ""
echo "РЕЗУЛЬТАТ:"
echo "  HTTPS настроен (самоподписанный сертификат)"
echo "  HTTP (80) → редирект на HTTPS (443)"
echo "  Сертификат: /etc/ssl/certs/org-server.crt"
echo "  Срок действия: 365 дней"
echo "OK"
