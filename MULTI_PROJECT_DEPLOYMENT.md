# nginx + certbot 멀티 프로젝트 배포 가이드

## 개요

이 가이드는 **하나의 리눅스 서버**에서 **여러 개의 웹서비스 프로젝트**를 운영하는 방법을 설명합니다.

### 아키텍처
```
리눅스 서버
├── nginx 프로젝트 (Git 관리) - 웹서버 인프라
│   ├── nginx (웹서버) - 포트 80, 443
│   ├── certbot (SSL 관리)
│   └── 서비스 관리 스크립트
└── 웹서비스 프로젝트들 (각각 별도 Git 관리)
    ├── 프로젝트 A (Next.js) - 포트 3000
    ├── 프로젝트 B (Node.js API) - 포트 3001
    ├── 프로젝트 C (WordPress) - 포트 80
    └── 프로젝트 D (정적 사이트) - 포트 8080
```

## 1단계: nginx 인프라 프로젝트 배포

### 1.1 프로젝트 클론 및 설정
```bash
# 서버에 nginx 인프라 프로젝트 클론
git clone <nginx-repo-url> /opt/nginx-infra
cd /opt/nginx-infra

# 환경 변수 설정
cd infrastructure/
cp env.example .env
nano .env  # 실제 값으로 수정
```

### 1.2 인프라 서비스 시작
```bash
# SSL 인증서 발급 및 인프라 시작
cd infrastructure/
docker compose -f docker-compose.prod.yml up -d

# 서비스 상태 확인
docker compose -f docker-compose.prod.yml ps
```

## 2단계: 웹서비스 프로젝트 배포

### 2.1 웹서비스 프로젝트 구조
각 웹서비스 프로젝트는 다음과 같은 구조를 가져야 합니다:

```
my-web-service/
├── src/                    # 소스 코드
├── Dockerfile             # 컨테이너 이미지 정의
├── docker-compose.yml     # 서비스 정의
├── .env                   # 환경 변수
└── README.md
```

### 2.2 웹서비스 docker-compose.yml 예시

**Next.js 프로젝트 예시:**
```yaml
version: '3.8'

services:
  my-nextjs-app:
    build: .
    container_name: my-nextjs-app
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_API_URL=https://api.mysite.com
    restart: unless-stopped
    networks:
      - web-services-network  # nginx 인프라와 동일한 네트워크

networks:
  web-services-network:
    external: true  # nginx 인프라에서 생성한 네트워크 사용
```

**Node.js API 프로젝트 예시:**
```yaml
version: '3.8'

services:
  my-api:
    build: .
    container_name: my-api
    environment:
      - NODE_ENV=production
      - PORT=3000
      - DATABASE_URL=${DATABASE_URL}
    restart: unless-stopped
    networks:
      - web-services-network

networks:
  web-services-network:
    external: true
```

### 2.3 웹서비스 배포 과정

```bash
# 1. 프로젝트 클론
git clone <web-service-repo-url> /opt/my-web-service
cd /opt/my-web-service

# 2. 환경 변수 설정
cp .env.example .env
nano .env

# 3. 서비스 시작
docker compose up -d

# 4. nginx 인프라에 서비스 추가
cd /opt/nginx-infra
./services/scripts/add-service.sh nextjs my-nextjs-app myapp.likeweb.co.kr 3000

# 5. SSL 인증서 발급
./certbot/init-letsencrypt.sh

# 6. nginx 재시작
docker compose -f docker-compose.prod.yml restart nginx
```

## 3단계: 서비스 관리

### 3.1 서비스 추가
```bash
# nginx 인프라 디렉토리에서 실행
./services/scripts/add-service.sh <서비스타입> <서비스명> <도메인> [포트]

# 예시
./services/scripts/add-service.sh nextjs blog blog.mysite.com 3000
./services/scripts/add-service.sh nodejs api api.mysite.com 3000
./services/scripts/add-service.sh wordpress wp wp.mysite.com 80
```

### 3.2 서비스 제거
```bash
# nginx 인프라 디렉토리에서 실행
./services/scripts/remove-service.sh <서비스명>

# 예시
./services/scripts/remove-service.sh blog
```

### 3.3 서비스 상태 확인
```bash
# 모든 컨테이너 상태 확인
docker ps

# 특정 서비스 로그 확인
docker logs my-nextjs-app
docker logs nginx-infra

# nginx 설정 테스트
docker compose -f docker-compose.prod.yml exec nginx nginx -t
```

## 4단계: 실제 배포 예시

### 4.1 메인 웹사이트 배포
```bash
# 1. 메인 웹사이트 프로젝트 배포
cd /opt
git clone https://github.com/user/main-website.git
cd main-website
docker compose up -d

# 2. nginx에 서비스 추가
cd /opt/nginx-infra
./services/scripts/add-service.sh nextjs main-website mysite.com 3000
```

### 4.2 API 서버 배포
```bash
# 1. API 서버 프로젝트 배포
cd /opt
git clone https://github.com/user/api-server.git
cd api-server
docker compose up -d

# 2. nginx에 서비스 추가
cd /opt/nginx-infra
./services/scripts/add-service.sh nodejs api-server api.mysite.com 3000
```

### 4.3 블로그 배포
```bash
# 1. WordPress 블로그 배포
cd /opt
git clone https://github.com/user/blog.git
cd blog
docker compose up -d

# 2. nginx에 서비스 추가
cd /opt/nginx-infra
./services/scripts/add-service.sh wordpress blog blog.mysite.com 80
```

## 5단계: 모니터링 및 유지보수

### 5.1 로그 모니터링
```bash
# 실시간 로그 확인
docker compose -f docker-compose.prod.yml logs -f nginx

# 특정 서비스 로그
docker logs -f my-nextjs-app
```

### 5.2 SSL 인증서 갱신
```bash
# 수동 갱신
docker compose -f docker-compose.prod.yml run --rm certbot renew

# 자동 갱신 (cron으로 설정됨)
# 매일 오후 12시에 자동 실행
```

### 5.3 백업
```bash
# SSL 인증서 백업
tar -czf certbot-backup.tar.gz certbot/conf/

# nginx 설정 백업
tar -czf nginx-config-backup.tar.gz nginx/
```

## 6단계: 트러블슈팅

### 6.1 일반적인 문제들

**서비스 연결 실패:**
```bash
# 네트워크 확인
docker network ls
docker network inspect web-services-network

# 컨테이너 상태 확인
docker ps
```

**SSL 인증서 문제:**
```bash
# 인증서 상태 확인
docker compose -f docker-compose.prod.yml exec certbot certbot certificates

# 인증서 재발급
docker compose -f docker-compose.prod.yml run --rm certbot certonly --webroot -w /var/www/certbot -d yourdomain.com
```

**nginx 설정 오류:**
```bash
# 설정 문법 검사
docker compose -f docker-compose.prod.yml exec nginx nginx -t

# 설정 다시 로드
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

## 7단계: 보안 고려사항

### 7.1 방화벽 설정
```bash
# 필요한 포트만 열기
ufw allow 22    # SSH
ufw allow 80     # HTTP
ufw allow 443    # HTTPS
ufw enable
```

### 7.2 정기 업데이트
```bash
# 시스템 업데이트
apt update && apt upgrade -y

# Docker 이미지 업데이트
docker compose pull
docker compose up -d
```

## 결론

이 구조를 사용하면:
- **확장성**: 새로운 웹서비스를 쉽게 추가/제거 가능
- **관리성**: 각 프로젝트를 독립적으로 관리
- **보안**: 중앙화된 SSL 인증서 관리
- **효율성**: 하나의 서버에서 여러 서비스 운영

각 웹서비스 프로젝트는 독립적인 Git 저장소로 관리하면서, nginx 인프라는 모든 서비스를 통합 관리하는 역할을 합니다.
