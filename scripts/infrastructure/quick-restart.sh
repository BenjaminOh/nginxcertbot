#!/bin/bash

# nginx 인프라 빠른 재시작 스크립트
# 사용법: ./quick-restart.sh

set -e

# 스크립트가 실행되는 디렉토리를 기준으로 프로젝트 루트 경로 설정
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

# 프로젝트 루트 확인
if [ ! -f "$PROJECT_ROOT/infrastructure/docker-compose.prod.yml" ]; then
    echo "nginx 프로젝트 루트에서 실행해주세요."
    echo "현재 경로: $(pwd)"
    echo "찾은 프로젝트 루트: $PROJECT_ROOT"
    exit 1
fi

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 현재 디렉토리 확인
if [ ! -f "../$PROJECT_ROOT/infrastructure/docker-compose.prod.yml" ]; then
    echo "nginx 프로젝트 루트에서 실행해주세요."
    exit 1
fi

log_warn "nginx 인프라 빠른 재시작 (1-2초 다운타임)"
log_info "서비스 중지 중..."
cd ../infrastructure/
docker compose -f docker-compose.prod.yml down

log_info "서비스 시작 중..."
docker compose -f docker-compose.prod.yml up -d

log_info "상태 확인 중..."
sleep 2
docker compose -f docker-compose.prod.yml ps

log_info "nginx 인프라 재시작 완료!"
