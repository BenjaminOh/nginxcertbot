#!/bin/bash

# 웹서비스 추가 스크립트
# 사용법: ./add-service.sh <서비스타입> <서비스명> <도메인> [포트]

set -e

# 스크립트가 실행되는 디렉토리를 기준으로 프로젝트 루트 경로 설정
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 함수 정의
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 인수 확인
if [ $# -lt 3 ]; then
    log_error "사용법: $0 <서비스타입> <서비스명> <도메인> [포트]"
    log_info "서비스타입: nextjs, nodejs, wordpress, static"
    log_info "예시: $0 nextjs my-app myapp.likeweb.co.kr 3000"
    exit 1
fi

SERVICE_TYPE=$1
SERVICE_NAME=$2
DOMAIN=$3
PORT=${4:-3000}

# 서비스 타입 검증
case $SERVICE_TYPE in
    nextjs|nodejs|wordpress|static)
        ;;
    *)
        log_error "지원하지 않는 서비스 타입: $SERVICE_TYPE"
        log_info "지원하는 타입: nextjs, nodejs, wordpress, static"
        exit 1
        ;;
esac

log_info "웹서비스 추가 시작..."
log_info "서비스 타입: $SERVICE_TYPE"
log_info "서비스명: $SERVICE_NAME"
log_info "도메인: $DOMAIN"
log_info "포트: $PORT"

# 현재 디렉토리 확인
if [ ! -f "../../$PROJECT_ROOT/infrastructure/docker-compose.prod.yml" ]; then
    log_error "nginx 프로젝트 루트에서 실행해주세요."
    exit 1
fi

# 1. nginx 서버 설정 파일 생성
log_info "nginx 서버 설정 파일 생성 중..."

case $SERVICE_TYPE in
    nextjs)
        cat > "$PROJECT_ROOT/nginx/conf.d/servers/${SERVICE_NAME}.conf" << EOF
# HTTP 서버 블록 - ${DOMAIN}
server {
    listen 80;
    server_name ${DOMAIN};
    
    # Let's Encrypt 인증서 발급을 위한 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # HTTP를 HTTPS로 리다이렉트
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS 서버 블록 - ${DOMAIN}
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    # SSL 인증서 설정
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    # SSL 보안 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Next.js 서비스로 프록시
    location / {
        proxy_pass http://${SERVICE_NAME}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
        ;;
    nodejs)
        cat > "$PROJECT_ROOT/nginx/conf.d/servers/${SERVICE_NAME}.conf" << EOF
# HTTP 서버 블록 - ${DOMAIN}
server {
    listen 80;
    server_name ${DOMAIN};
    
    # Let's Encrypt 인증서 발급을 위한 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # HTTP를 HTTPS로 리다이렉트
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS 서버 블록 - ${DOMAIN}
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    # SSL 인증서 설정
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    # SSL 보안 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 헬스체크
    location /health {
        proxy_pass http://${SERVICE_NAME}/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API 서비스로 프록시
    location / {
        proxy_pass http://${SERVICE_NAME}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
        ;;
    wordpress)
        cat > "$PROJECT_ROOT/nginx/conf.d/servers/${SERVICE_NAME}.conf" << EOF
# HTTP 서버 블록 - ${DOMAIN}
server {
    listen 80;
    server_name ${DOMAIN};
    
    # Let's Encrypt 인증서 발급을 위한 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # HTTP를 HTTPS로 리다이렉트
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS 서버 블록 - ${DOMAIN}
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    # SSL 인증서 설정
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    # SSL 보안 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # WordPress 서비스로 프록시
    location / {
        proxy_pass http://${SERVICE_NAME}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
    }
}
EOF
        ;;
esac

# 2. 업스트림 설정 추가
log_info "업스트림 설정 추가 중..."

# 업스트림 설정이 이미 있는지 확인
if grep -q "upstream ${SERVICE_NAME}" $PROJECT_ROOT/nginx/conf.d/upstreams.conf; then
    log_warn "업스트림 설정이 이미 존재합니다: ${SERVICE_NAME}"
else
    echo "" >> $PROJECT_ROOT/nginx/conf.d/upstreams.conf
    echo "upstream ${SERVICE_NAME} {" >> $PROJECT_ROOT/nginx/conf.d/upstreams.conf
    echo "    server ${SERVICE_NAME}:${PORT};" >> $PROJECT_ROOT/nginx/conf.d/upstreams.conf
    echo "}" >> $PROJECT_ROOT/nginx/conf.d/upstreams.conf
fi

# 3. 환경 변수 파일 업데이트
log_info "환경 변수 파일 업데이트 중..."

if [ -f "$PROJECT_ROOT/infrastructure/.env" ]; then
    # CERTBOT_DOMAIN에 새 도메인 추가
    if ! grep -q "${DOMAIN}" $PROJECT_ROOT/infrastructure/.env; then
        sed -i.bak "s/CERTBOT_DOMAIN=.*/CERTBOT_DOMAIN=${CERTBOT_DOMAIN},${DOMAIN}/" $PROJECT_ROOT/infrastructure/.env
        log_info "환경 변수 파일에 도메인 추가됨: ${DOMAIN}"
    fi
else
    log_warn ".env 파일이 없습니다. 수동으로 도메인을 추가해주세요: ${DOMAIN}"
fi

# 4. nginx 설정 테스트
log_info "nginx 설정 테스트 중..."
if docker compose -f $PROJECT_ROOT/infrastructure/docker-compose.prod.yml exec nginx nginx -t 2>/dev/null; then
    log_info "nginx 설정이 유효합니다."
else
    log_warn "nginx 컨테이너가 실행 중이지 않습니다. 나중에 테스트해주세요."
fi

# 5. SSL 인증서 발급
log_info "SSL 인증서 발급 중..."
log_info "도메인: ${DOMAIN}"

# nginx 재시작 (새 설정 적용)
log_info "nginx 재시작 중..."
docker compose -f $PROJECT_ROOT/infrastructure/docker-compose.prod.yml restart nginx

# 잠시 대기 (nginx 시작 대기)
sleep 5

# SSL 인증서 발급
log_info "Let's Encrypt 인증서 발급 시도 중..."
if docker compose -f $PROJECT_ROOT/infrastructure/docker-compose.prod.yml run --rm certbot certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email admin@${DOMAIN} \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d ${DOMAIN}; then
    log_info "SSL 인증서 발급 성공: ${DOMAIN}"
    
    # nginx 재시작 (SSL 인증서 적용)
    log_info "SSL 인증서 적용을 위해 nginx 재시작 중..."
    docker compose -f $PROJECT_ROOT/infrastructure/docker-compose.prod.yml restart nginx
    
    log_info "웹서비스 추가 완료!"
    log_info "도메인 접속 테스트: https://${DOMAIN}"
else
    log_error "SSL 인증서 발급 실패: ${DOMAIN}"
    log_warn "수동으로 인증서를 발급해주세요:"
    log_warn "docker compose -f $PROJECT_ROOT/infrastructure/docker-compose.prod.yml run --rm certbot certbot certonly --webroot --webroot-path=/var/www/certbot --email admin@${DOMAIN} --agree-tos --no-eff-email -d ${DOMAIN}"
fi

log_info "다음 단계:"
log_info "1. 웹서비스 프로젝트를 서버에 배포"
log_info "2. docker-compose.yml에서 네트워크를 'web-services-network'로 설정"
log_info "3. 도메인 접속 테스트: https://${DOMAIN}"
