# nginx + certbot 웹서버 인프라 프로젝트

이 프로젝트는 리눅스 서버에서 여러 웹서비스를 운영하기 위한 nginx + certbot 인프라입니다.

## 프로젝트 구조

```
nginx/
├── infrastructure/          # nginx + certbot 인프라
│   ├── docker-compose.prod.yml  # 인프라 서비스만 포함
│   └── env.example              # 환경 변수 템플릿
├── nginx/                    # nginx 설정
│   ├── Dockerfile
│   ├── nginx.conf           # 메인 설정 파일
│   └── conf.d/              # 추가 설정 파일들
│       ├── upstreams.conf   # 업스트림 서버 정의
│       └── servers/         # 서버 블록 설정들
├── certbot/                 # SSL 인증서 관리
│   ├── Dockerfile
│   ├── init-letsencrypt.sh
│   ├── renew.sh
│   ├── conf/                # SSL 인증서 저장소
│   └── www/                 # 웹루트 인증용
├── services/                # 웹서비스 설정 템플릿
│   ├── templates/           # 서비스별 설정 템플릿
│   │   ├── nextjs-template.md
│   │   ├── nodejs-template.md
│   │   └── wordpress-template.md
│   └── scripts/             # 서비스 관리 스크립트
│       ├── add-service.sh
│       └── remove-service.sh
├── DEPLOYMENT.md            # 기본 배포 가이드
├── MULTI_PROJECT_DEPLOYMENT.md  # 멀티 프로젝트 배포 가이드
└── README.md
```

## 사용 방법

1. **인프라 배포**: 
   ```bash
   cd infrastructure/
   
   # 환경 변수 설정
   cp env.example .env
   nano .env  # 실제 도메인과 이메일로 수정
   
   # 인프라 시작
   docker compose -f docker-compose.prod.yml up -d
   ```

2. **웹서비스 추가**: 
   ```bash
   # 프로젝트 루트에서 실행
   ./services/scripts/add-service.sh nextjs my-app myapp.com 3000
   ```

3. **자동 관리**: 스크립트를 통해 서비스 추가/제거 자동화

## 인프라 관리 스크립트

### 빠른 재시작 (1-2초 다운타임)
```bash
./quick-restart.sh
```

### 완전 재시작 (옵션 포함)
```bash
# 기본 재시작
./restart-infrastructure.sh

# 이미지 재빌드 후 시작
./restart-infrastructure.sh --rebuild

# 빠른 재시작 (재빌드 없음)
./restart-infrastructure.sh --quick

# 확인 없이 강제 실행
./restart-infrastructure.sh --force

# 도움말
./restart-infrastructure.sh --help
```

### 테스트 → 프로덕션 전환
```bash
./switch-to-production.sh
```

## 환경 변수 설정

### 필수 설정
```bash
# SSL 인증서 발급 도메인 (쉼표로 구분)
CERTBOT_DOMAIN=mysite.com,api.mysite.com

# SSL 인증서 발급 이메일
CERTBOT_EMAIL=admin@mysite.com

# 테스트 환경 (처음에는 1, 테스트 후 0으로 변경)
CERTBOT_STAGING=1
```

### 선택 설정 (고급 사용자용)
```bash
# nginx 성능 최적화 (필요시에만)
# NGINX_WORKER_PROCESSES=auto
# NGINX_WORKER_CONNECTIONS=2048

# 로그 설정 (필요시에만)
# NGINX_LOG_LEVEL=warn
```

## 지원하는 웹서비스 타입

- Next.js 애플리케이션
- Node.js API 서버
- WordPress 블로그
- React/Vue.js SPA
- 정적 웹사이트
- 기타 HTTP 서비스
