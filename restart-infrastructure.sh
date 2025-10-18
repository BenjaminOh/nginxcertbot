#!/bin/bash

# nginx 인프라 완전 재시작 스크립트
# 사용법: ./restart-infrastructure.sh [옵션]

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 옵션 파싱
REBUILD=false
FORCE=false
QUICK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild)
            REBUILD=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --quick)
            QUICK=true
            shift
            ;;
        -h|--help)
            echo "nginx 인프라 재시작 스크립트"
            echo ""
            echo "사용법: $0 [옵션]"
            echo ""
            echo "옵션:"
            echo "  --rebuild    이미지 재빌드 후 시작"
            echo "  --force      확인 없이 강제 실행"
            echo "  --quick      빠른 재시작 (재빌드 없음)"
            echo "  -h, --help   도움말 표시"
            echo ""
            echo "예시:"
            echo "  $0                    # 기본 재시작"
            echo "  $0 --rebuild          # 이미지 재빌드 후 시작"
            echo "  $0 --quick            # 빠른 재시작"
            echo "  $0 --force --rebuild  # 확인 없이 재빌드 후 시작"
            exit 0
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            echo "도움말을 보려면: $0 --help"
            exit 1
            ;;
    esac
done

# 현재 디렉토리 확인
if [ ! -f "infrastructure/docker-compose.prod.yml" ]; then
    log_error "nginx 프로젝트 루트에서 실행해주세요."
    exit 1
fi

# 환경 변수 파일 확인
if [ ! -f "infrastructure/.env" ]; then
    log_error "infrastructure/.env 파일이 없습니다."
    log_info "infrastructure/env.example을 .env로 복사하고 설정해주세요."
    exit 1
fi

# 확인 메시지
if [ "$FORCE" = false ]; then
    log_warn "nginx 인프라를 완전히 재시작합니다."
    log_warn "서비스 장애가 1-2초 발생할 수 있습니다."
    
    if [ "$REBUILD" = true ]; then
        log_warn "이미지 재빌드가 포함되어 시간이 더 오래 걸릴 수 있습니다."
    fi
    
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "취소되었습니다."
        exit 0
    fi
fi

log_info "nginx 인프라 재시작 시작..."

# 1단계: 현재 상태 확인
log_step "1/6 현재 상태 확인"
cd infrastructure/

# 실행 중인 컨테이너 확인
RUNNING_CONTAINERS=$(docker compose -f docker-compose.prod.yml ps --services --filter "status=running" 2>/dev/null || echo "")
if [ -n "$RUNNING_CONTAINERS" ]; then
    log_info "실행 중인 컨테이너: $RUNNING_CONTAINERS"
else
    log_info "실행 중인 컨테이너가 없습니다."
fi

# 2단계: 서비스 중지
log_step "2/6 서비스 중지"
log_info "nginx 인프라 서비스 중지 중..."
docker compose -f docker-compose.prod.yml down
log_info "서비스 중지 완료"

# 3단계: 이미지 정리 (선택사항)
if [ "$REBUILD" = true ]; then
    log_step "3/6 이미지 정리 및 재빌드"
    log_info "기존 이미지 제거 중..."
    docker compose -f docker-compose.prod.yml build --no-cache
    log_info "이미지 재빌드 완료"
else
    log_step "3/6 이미지 정리 (건너뜀)"
    log_info "재빌드 옵션이 없어 이미지 정리를 건너뜁니다."
fi

# 4단계: 볼륨 정리 (선택사항)
if [ "$FORCE" = true ]; then
    log_step "4/6 볼륨 정리"
    log_warn "강제 모드: 모든 볼륨을 제거합니다."
    docker compose -f docker-compose.prod.yml down -v
    log_info "볼륨 정리 완료"
else
    log_step "4/6 볼륨 정리 (건너뜀)"
    log_info "볼륨은 유지됩니다."
fi

# 5단계: 서비스 시작
log_step "5/6 서비스 시작"
log_info "nginx 인프라 서비스 시작 중..."
docker compose -f docker-compose.prod.yml up -d
log_info "서비스 시작 완료"

# 6단계: 상태 확인
log_step "6/6 상태 확인"
log_info "서비스 상태 확인 중..."
sleep 3

# 컨테이너 상태 확인
docker compose -f docker-compose.prod.yml ps

# nginx 설정 테스트
log_info "nginx 설정 테스트 중..."
if docker compose -f docker-compose.prod.yml exec nginx nginx -t; then
    log_info "nginx 설정이 유효합니다."
else
    log_error "nginx 설정에 오류가 있습니다."
    exit 1
fi

# SSL 인증서 상태 확인
log_info "SSL 인증서 상태 확인 중..."
if docker compose -f docker-compose.prod.yml exec certbot certbot certificates 2>/dev/null; then
    log_info "SSL 인증서 상태 확인 완료"
else
    log_warn "SSL 인증서가 없거나 확인할 수 없습니다."
fi

# 완료 메시지
log_info "nginx 인프라 재시작 완료!"
log_info "서비스 상태:"
docker compose -f docker-compose.prod.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

log_info "다음 단계:"
log_info "1. 웹사이트 접속하여 서비스 확인"
log_info "2. SSL 인증서 상태 확인"
log_info "3. 로그 확인: docker compose -f docker-compose.prod.yml logs -f"
