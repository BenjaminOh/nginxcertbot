#!/bin/bash

# Let's Encrypt 인증서 초기화 스크립트

# .env 파일에서 환경변수 로드
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "### .env 파일에서 환경변수를 로드했습니다."
else
    echo "### 경고: .env 파일을 찾을 수 없습니다. 기본값을 사용합니다."
fi

# 환경 변수 설정 (기본값 포함)
domains=${CERTBOT_DOMAIN:-aphennet.likeweb.co.kr}
rsa_key_size=4096
data_path="./certbot"
email=${CERTBOT_EMAIL:-admin@likeweb.co.kr}
staging=${CERTBOT_STAGING:-0} # 0으로 설정하면 프로덕션 환경

# 도메인 설정 확인
if [ "$domains" = "yourdomain.com" ] || [ "$domains" = "localhost" ]; then
    echo "### 경고: 기본 도메인($domains)이 설정되어 있습니다."
    echo "### .env 파일에서 CERTBOT_DOMAIN을 실제 도메인으로 변경해주세요."
    echo "### 예: CERTBOT_DOMAIN=example.com"
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi 

# 이메일 설정 확인
if [ "$email" = "your-email@example.com" ]; then
    echo "### 경고: 기본 이메일(your-email@example.com)이 설정되어 있습니다."
    echo "### .env 파일에서 CERTBOT_EMAIL을 실제 이메일로 변경해주세요."
    echo "### 예: CERTBOT_EMAIL=admin@example.com"
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# certbot 디렉토리 생성
mkdir -p "$data_path/conf/live/$domains"

# 기존 인증서가 있는지 확인
if [ -d "$data_path/conf/live/$domains" ]; then
    read -p "기존 인증서가 있습니다. 계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Docker Compose로 nginx와 certbot 실행
echo "### nginx와 certbot 컨테이너 시작 중..."
docker compose -f docker-compose.prod.yml up -d nginx

echo "### certbot 컨테이너 시작 중..."
docker compose -f docker-compose.prod.yml up -d certbot

# nginx가 시작될 때까지 대기
echo "### nginx가 시작될 때까지 대기 중..."
sleep 10

# certbot으로 인증서 요청
echo "### Let's Encrypt 인증서 요청 중..."

# staging 환경인지 확인
if [ $staging != "0" ]; then
    staging_arg="--staging"
    echo "### 테스트 환경 (staging) 모드로 실행 중..."
else
    staging_arg=""
    echo "### 프로덕션 환경으로 실행 중..."
fi

# certbot으로 인증서 요청
# 주의: localhost는 Let's Encrypt에서 인증서를 발급받을 수 없습니다
# 실제 도메인이 필요합니다
if [ "$domains" = "localhost" ] || [ "$domains" = "yourdomain.com" ]; then
    echo "### 경고: $domains는 Let's Encrypt에서 인증서를 발급받을 수 없습니다."
    echo "### .env 파일에서 CERTBOT_DOMAIN을 실제 도메인으로 변경해주세요."
    echo "### 예: CERTBOT_DOMAIN=example.com"
    exit 1
fi

# 도메인을 쉼표로 분리하여 배열로 변환
IFS=',' read -ra DOMAIN_ARRAY <<< "$domains"

# certbot 명령어 구성
certbot_cmd="docker compose -f docker-compose.prod.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $email \
    --agree-tos \
    --no-eff-email \
    $staging_arg"

# 각 도메인에 대해 -d 옵션 추가
for domain in "${DOMAIN_ARRAY[@]}"; do
    domain=$(echo $domain | xargs)  # 공백 제거
    certbot_cmd="$certbot_cmd -d $domain"
done

# certbot 실행
eval $certbot_cmd

# nginx 설정 다시 로드
echo "### nginx 설정 다시 로드 중..."
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

echo "### 인증서 설정 완료!"
echo "### HTTPS로 접속 가능합니다: https://$domains"
