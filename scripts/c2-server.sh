#!/bin/bash
# c2-server first-boot setup: nginx with a self-signed certificate and a
# /checkin endpoint for the benign beacon experiment.
set -uo pipefail
exec > >(tee -a /var/log/blog-lab-setup.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

mkdir -p /var/lib/blog-lab

apt-get update
apt-get install -y nginx openssl

# Deliberately self-signed with a vague, legitimate-sounding CN. Certificate
# oddities are one of the signals the post shows a defender can see.
mkdir -p /etc/nginx/tls
openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
  -keyout /etc/nginx/tls/c2.key -out /etc/nginx/tls/c2.crt \
  -subj "/CN=update-service.local"
chmod 600 /etc/nginx/tls/c2.key

cat > /etc/nginx/sites-available/c2 <<'EOF'
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/tls/c2.crt;
    ssl_certificate_key /etc/nginx/tls/c2.key;

    access_log /var/log/nginx/c2_access.log;

    location = /checkin {
        default_type application/json;
        return 200 '{"status":"ok"}';
    }

    location / {
        return 404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/c2 /etc/nginx/sites-enabled/c2
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

touch /var/lib/blog-lab/setup-done
echo "=== c2-server setup complete"
