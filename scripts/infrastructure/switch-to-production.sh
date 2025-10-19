#!/bin/bash

# Let's Encrypt 테스트 → 프로덕션 전환 스크립트
# 사용법: ./switch-to-production.sh

set -e

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

# 현재 디렉토리 확인
if [ ! -f "../infrastructure/docker-compose.prod.yml" ]; then
    log_error "nginx 프로젝트 루트에서 실행해주세요."
    exit 1
fi

log_info "Let's Encrypt 테스트 → 프로덕션 전환 시작..."

# 1. 환경 변수 파일 확인
if [ ! -f "../infrastructure/.env" ]; then
    log_error "infrastructure/.env 파일이 없습니다."
    log_info "infrastructure/env.example을 .env로 복사하고 설정해주세요."
    exit 1
fi

# 2. 현재 설정 확인
CURRENT_STAGING=$(grep "CERTBOT_STAGING=" ../infrastructure/.env | cut -d'=' -f2)
if [ "$CURRENT_STAGING" = "0" ]; then
    log_warn "이미 프로덕션 환경으로 설정되어 있습니다."
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# 3. 환경 변수 변경
log_info "환경 변수를 프로덕션으로 변경 중..."
sed -i.bak 's/CERTBOT_STAGING=1/CERTBOT_STAGING=0/' ../infrastructure/.env
log_info "환경 변수 변경 완료"

# 4. certbot 컨테이너 재시작
log_info "certbot 컨테이너 재시작 중..."
docker compose -f ../infrastructure/docker-compose.prod.yml restart certbot
log_info "certbot 컨테이너 재시작 완료"

# 5. 프로덕션 인증서 발급
log_info "프로덕션 SSL 인증서 발급 중..."
log_warn "이 과정은 1-2분 소요될 수 있습니다..."

# 환경 변수에서 도메인과 이메일 추출
DOMAINS=$(grep "CERTBOT_DOMAIN=" ../infrastructure/.env | cut -d'=' -f2)
EMAIL=$(grep "CERTBOT_EMAIL=" ../infrastructure/.env | cut -d'=' -f2)

# 도메인을 배열로 변환
IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"

# certbot 명령어 구성
CERTBOT_CMD="docker compose -f ../infrastructure/docker-compose.prod.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email"

# 각 도메인에 대해 -d 옵션 추가
for domain in "${DOMAIN_ARRAY[@]}"; do
    domain=$(echo $domain | xargs)  # 공백 제거
    CERTBOT_CMD="$CERTBOT_CMD -d $domain"
done

# certbot 실행
if eval $CERTBOT_CMD; then
    log_info "프로덕션 SSL 인증서 발급 완료!"
else
    log_error "SSL 인증서 발급 실패"
    log_info "백업 파일에서 복원 중..."
    mv ../infrastructure/.env.bak ../infrastructure/.env
    exit 1
fi

# 6. nginx 설정 다시 로드
log_info "nginx 설정 다시 로드 중..."
if docker compose -f ../infrastructure/docker-compose.prod.yml exec nginx nginx -s reload; then
    log_info "nginx 설정 다시 로드 완료"
else
    log_warn "nginx reload 실패, 전체 재시작 시도 중..."
    docker compose -f ../infrastructure/docker-compose.prod.yml restart nginx
    log_info "nginx 전체 재시작 완료"
fi

# 7. 완료 메시지
log_info "테스트 → 프로덕션 전환 완료!"
log_info "다음 단계:"
log_info "1. 웹사이트 접속하여 SSL 인증서 확인"
log_info "2. 브라우저에서 🔒 아이콘 확인"
log_info "3. 백업 파일 정리: rm infrastructure/.env.bak"
