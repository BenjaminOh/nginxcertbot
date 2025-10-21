#!/bin/bash

# SSL 인증서 자동 발급 스크립트
# aphen.net 도메인에 대한 Let's Encrypt SSL 인증서 발급

set -e

# 환경 변수 설정
DOMAIN="aphen.net"
EMAIL="admin@aphen.net"  # 실제 이메일로 변경 필요
STAGING="--staging"  # 테스트용, 실제 발급시에는 제거

echo "🔐 SSL 인증서 발급을 시작합니다..."
echo "도메인: $DOMAIN"
echo "이메일: $EMAIL"

# nginx 컨테이너가 실행 중인지 확인
if ! docker ps | grep -q nginx-infra; then
    echo "❌ nginx 컨테이너가 실행 중이 아닙니다."
    echo "먼저 nginx를 시작해주세요:"
    echo "cd /Users/benjaminoh/dev/project/aphennet/nginx && docker-compose -f infrastructure/docker-compose.prod.yml up -d"
    exit 1
fi

# certbot으로 SSL 인증서 발급
echo "📋 SSL 인증서를 발급받는 중..."
docker run --rm \
    -v /Users/benjaminoh/dev/project/aphennet/nginx/certbot/conf:/etc/letsencrypt \
    -v /Users/benjaminoh/dev/project/aphennet/nginx/certbot/www:/var/www/certbot \
    certbot/certbot \
    certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    $STAGING \
    -d $DOMAIN \
    -d www.$DOMAIN

echo "✅ SSL 인증서 발급 완료!"

# SSL 설정이 포함된 nginx 설정 생성
echo "🔧 SSL 설정을 포함한 nginx 설정을 생성합니다..."

cat > /Users/benjaminoh/dev/project/aphennet/nginx/nginx/conf.d/servers/aphennet-ssl.conf << 'EOF'
# SSL이 포함된 aphen.net 도메인 설정
server {
    listen 80;
    server_name aphen.net www.aphen.net;
    
    # HTTP에서 HTTPS로 리다이렉트
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name aphen.net www.aphen.net;

    # SSL 인증서 설정
    ssl_certificate /etc/letsencrypt/live/aphen.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/aphen.net/privkey.pem;
    
    # SSL 보안 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # SSL 인증서 갱신을 위한 ACME Challenge 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }

    # 모든 요청을 Next.js로 프록시
    location / {
        proxy_pass http://aphennet-nextjs:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

echo "🔄 nginx를 재시작하여 SSL 설정을 적용합니다..."
cd /Users/benjaminoh/dev/project/aphennet/nginx
docker-compose -f infrastructure/docker-compose.prod.yml restart nginx

echo "🎉 SSL 설정 완료!"
echo "이제 https://aphen.net 으로 접근할 수 있습니다."
echo ""
echo "📝 참고사항:"
echo "- 테스트용 인증서가 발급되었습니다 (staging 모드)"
echo "- 실제 운영용 인증서를 발급하려면 스크립트에서 --staging 옵션을 제거하세요"
echo "- SSL 인증서는 90일마다 갱신이 필요합니다"
