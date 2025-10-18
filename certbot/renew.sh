#!/bin/bash

# Let's Encrypt 인증서 자동 갱신 스크립트

echo "### 인증서 갱신 시작..."

# certbot으로 인증서 갱신
docker compose -f docker-compose.prod.yml run --rm certbot renew

# nginx 설정 다시 로드
echo "### nginx 설정 다시 로드 중..."
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

echo "### 인증서 갱신 완료!"
