#!/bin/bash

# 운영서버에서 기존 서비스들을 nginx 인프라에 연결하는 스크립트
# 사용법: ./connect-existing-services.sh

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log_info "운영서버 기존 서비스 연결 시작..."

# 현재 디렉토리 확인
if [ ! -f "../infrastructure/docker-compose.prod.yml" ]; then
    log_error "nginx 프로젝트 루트에서 실행해주세요."
    exit 1
fi

# 1단계: 기존 컨테이너 상태 확인
log_step "1/6 기존 컨테이너 상태 확인"
log_info "현재 실행 중인 컨테이너들:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 필요한 컨테이너들이 실행 중인지 확인
REQUIRED_CONTAINERS=("aphennet-nodejs" "aphennet-nextjs" "aphennet-mariadb")
MISSING_CONTAINERS=()

for container in "${REQUIRED_CONTAINERS[@]}"; do
    if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        MISSING_CONTAINERS+=("$container")
    fi
done

if [ ${#MISSING_CONTAINERS[@]} -gt 0 ]; then
    log_error "다음 컨테이너들이 실행 중이지 않습니다: ${MISSING_CONTAINERS[*]}"
    log_info "먼저 기존 서비스들을 시작해주세요."
    exit 1
fi

log_info "모든 필요한 컨테이너가 실행 중입니다."

# 2단계: nginx 인프라 시작
log_step "2/6 nginx 인프라 시작"
log_info "nginx 인프라 시작 중..."
cd ../infrastructure/
docker compose -f docker-compose.prod.yml up -d
cd ../scripts/

# 3단계: 기존 컨테이너들을 nginx 네트워크에 연결
log_step "3/6 기존 컨테이너들을 nginx 네트워크에 연결"

# nginx 네트워크 이름 확인
NGINX_NETWORK=$(docker compose -f ../infrastructure/docker-compose.prod.yml config --services | head -1 | xargs -I {} docker compose -f ../infrastructure/docker-compose.prod.yml config | grep -A 10 "networks:" | grep -v "networks:" | head -1 | awk '{print $1}' | sed 's/://')
if [ -z "$NGINX_NETWORK" ]; then
    NGINX_NETWORK="web-services-network"
fi

log_info "nginx 네트워크: $NGINX_NETWORK"

# 각 컨테이너를 nginx 네트워크에 연결
for container in "${REQUIRED_CONTAINERS[@]}"; do
    log_info "컨테이너 $container 를 nginx 네트워크에 연결 중..."
    if docker network connect $NGINX_NETWORK $container 2>/dev/null; then
        log_info "컨테이너 $container 연결 완료"
    else
        log_warn "컨테이너 $container 가 이미 연결되어 있거나 연결 실패"
    fi
done

# 4단계: 네트워크 연결 확인
log_step "4/6 네트워크 연결 확인"
log_info "nginx 네트워크에 연결된 컨테이너들:"
docker network inspect $NGINX_NETWORK --format "{{range .Containers}}{{.Name}} {{end}}"

# 5단계: nginx 설정 테스트
log_step "5/6 nginx 설정 테스트"
log_info "nginx 설정 문법 검사 중..."
if docker compose -f ../infrastructure/docker-compose.prod.yml exec nginx nginx -t; then
    log_info "nginx 설정이 유효합니다."
else
    log_error "nginx 설정에 오류가 있습니다."
    exit 1
fi

# 6단계: SSL 인증서 발급
log_step "6/6 SSL 인증서 발급"
log_info "SSL 인증서 발급 중..."
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
    log_info "SSL 인증서 발급 완료!"
else
    log_error "SSL 인증서 발급 실패"
    log_info "수동으로 발급해주세요:"
    echo "$CERTBOT_CMD"
fi

# nginx 설정 다시 로드
log_info "nginx 설정 다시 로드 중..."
docker compose -f ../infrastructure/docker-compose.prod.yml exec nginx nginx -s reload

# 완료 메시지
log_info "운영서버 기존 서비스 연결 완료!"
log_info "서비스 상태:"
docker compose -f ../infrastructure/docker-compose.prod.yml ps

log_info "다음 단계:"
log_info "1. 웹사이트 접속하여 서비스 확인:"
log_info "   - https://aphennet.likeweb.co.kr (Next.js)"
log_info "   - https://aphennetapi.likeweb.co.kr (Node.js API)"
log_info "2. SSL 인증서 상태 확인"
log_info "3. 로그 확인: docker compose -f ../infrastructure/docker-compose.prod.yml logs -f"
