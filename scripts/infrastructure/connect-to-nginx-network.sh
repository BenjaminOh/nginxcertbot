#!/bin/bash

# 기존 서비스들을 nginx 네트워크에 연결하는 스크립트
# 운영서버에서 실행

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "기존 서비스들을 nginx 네트워크에 연결 중..."

# nginx 네트워크 이름 확인
NGINX_NETWORK="infrastructure_web-services-network"

# 기존 컨테이너들을 nginx 네트워크에 연결
log_info "aphennet-nextjs 컨테이너를 nginx 네트워크에 연결 중..."
docker network connect $NGINX_NETWORK aphennet-nextjs

log_info "aphennet-nodejs 컨테이너를 nginx 네트워크에 연결 중..."
docker network connect $NGINX_NETWORK aphennet-nodejs

log_info "aphennet-mariadb 컨테이너를 nginx 네트워크에 연결 중..."
docker network connect $NGINX_NETWORK aphennet-mariadb

# 네트워크 연결 상태 확인
log_info "네트워크 연결 상태 확인:"
docker network inspect $NGINX_NETWORK --format '{{range .Containers}}{{.Name}} {{end}}'

log_success "모든 서비스가 nginx 네트워크에 연결되었습니다!"

# nginx 설정 테스트
log_info "nginx 설정 테스트 중..."
docker compose -f ../infrastructure/docker-compose.prod.yml exec nginx nginx -t

if [ $? -eq 0 ]; then
    log_success "nginx 설정이 올바릅니다!"
    
    # nginx 재시작
    log_info "nginx 재시작 중..."
    docker compose -f ../infrastructure/docker-compose.prod.yml restart nginx
    
    log_success "nginx가 성공적으로 재시작되었습니다!"
else
    log_error "nginx 설정에 오류가 있습니다."
    exit 1
fi

# 최종 상태 확인
log_info "최종 서비스 상태:"
docker compose -f ../infrastructure/docker-compose.prod.yml ps

log_success "기존 서비스 연결 완료!"
log_info "이제 다음 도메인으로 접속할 수 있습니다:"
log_info "- https://aphen.net (Next.js 프론트엔드)"
log_info "- https://api.aphen.net (Node.js API)"
