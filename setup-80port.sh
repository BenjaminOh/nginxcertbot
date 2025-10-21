#!/bin/bash

# 80번 포트만 추가하는 간단한 스크립트
# aphen.net 도메인으로 HTTP 접근 가능하도록 설정

set -e

echo "🌐 80번 포트 설정을 시작합니다..."
echo "도메인: aphen.net"

# nginx 컨테이너가 실행 중인지 확인
if ! docker ps | grep -q nginx-infra; then
    echo "❌ nginx 컨테이너가 실행 중이 아닙니다."
    echo "먼저 nginx를 시작해주세요:"
    echo "cd /path/to/nginx && docker-compose -f infrastructure/docker-compose.prod.yml up -d"
    exit 1
fi

# 간단한 80번 포트 설정 생성
echo "📋 80번 포트 설정을 생성합니다..."

cat > /Users/benjaminoh/dev/project/aphennet/nginx/nginx/conf.d/servers/aphennet-80.conf << 'EOF'
# 80번 포트만 사용하는 간단한 aphen.net 설정
server {
    listen 80;
    server_name aphen.net www.aphen.net;

    # SSL 인증서 발급을 위한 ACME Challenge 경로
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
        
        # 프록시 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

echo "🔄 nginx를 재시작하여 80번 포트 설정을 적용합니다..."
cd /Users/benjaminoh/dev/project/aphennet/nginx
docker-compose -f infrastructure/docker-compose.prod.yml restart nginx

echo "✅ 80번 포트 설정 완료!"
echo "이제 http://aphen.net 으로 접근할 수 있습니다."
echo ""
echo "📝 다음 단계:"
echo "- 도메인이 정상적으로 접근되는지 확인"
echo "- SSL 인증서 발급을 원한다면 ./ssl-setup.sh 실행"
