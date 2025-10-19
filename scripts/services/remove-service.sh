#!/bin/bash

# 웹서비스 제거 스크립트
# 사용법: ./remove-service.sh <서비스명>

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

# 인수 확인
if [ $# -lt 1 ]; then
    log_error "사용법: $0 <서비스명>"
    log_info "예시: $0 my-app"
    exit 1
fi

SERVICE_NAME=$1

log_info "웹서비스 제거 시작..."
log_info "서비스명: $SERVICE_NAME"

# 현재 디렉토리 확인
if [ ! -f "infrastructure/docker-compose.prod.yml" ]; then
    log_error "nginx 프로젝트 루트에서 실행해주세요."
    exit 1
fi

# 1. nginx 서버 설정 파일 제거
SERVER_CONFIG_FILE="nginx/conf.d/servers/${SERVICE_NAME}.conf"
if [ -f "$SERVER_CONFIG_FILE" ]; then
    rm "$SERVER_CONFIG_FILE"
    log_info "nginx 서버 설정 파일 제거됨: $SERVER_CONFIG_FILE"
else
    log_warn "nginx 서버 설정 파일이 없습니다: $SERVER_CONFIG_FILE"
fi

# 2. 업스트림 설정 제거
UPSTREAM_FILE="nginx/conf.d/upstreams.conf"
if [ -f "$UPSTREAM_FILE" ]; then
    # 업스트림 블록 제거 (sed를 사용하여 해당 업스트림 블록 삭제)
    sed -i.bak "/^upstream ${SERVICE_NAME} {$/,/^}$/d" "$UPSTREAM_FILE"
    log_info "업스트림 설정 제거됨: ${SERVICE_NAME}"
else
    log_warn "업스트림 설정 파일이 없습니다: $UPSTREAM_FILE"
fi

# 3. 환경 변수 파일에서 도메인 제거 (선택사항)
if [ -f ".env" ]; then
    log_info "환경 변수 파일에서 도메인을 수동으로 제거해주세요."
    log_info "CERTBOT_DOMAIN에서 해당 도메인을 제거하세요."
fi

# 4. nginx 설정 테스트
log_info "nginx 설정 테스트 중..."
if docker compose -f infrastructure/docker-compose.prod.yml exec nginx nginx -t 2>/dev/null; then
    log_info "nginx 설정이 유효합니다."
else
    log_warn "nginx 컨테이너가 실행 중이지 않습니다. 나중에 테스트해주세요."
fi

log_info "웹서비스 제거 완료!"
log_info "다음 단계:"
log_info "1. 웹서비스 컨테이너 중지 및 제거"
log_info "2. nginx 재시작: docker compose -f infrastructure/docker-compose.prod.yml restart nginx"
log_info "3. SSL 인증서 정리 (선택사항): certbot delete --cert-name <도메인>"
