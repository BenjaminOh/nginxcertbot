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
   cp env.example .env
   docker compose -f docker-compose.prod.yml up -d
   ```

2. **웹서비스 추가**: 
   ```bash
   # 프로젝트 루트에서 실행
   ./services/scripts/add-service.sh nextjs my-app myapp.com 3000
   ```

3. **자동 관리**: 스크립트를 통해 서비스 추가/제거 자동화

## 지원하는 웹서비스 타입

- Next.js 애플리케이션
- Node.js API 서버
- WordPress 블로그
- React/Vue.js SPA
- 정적 웹사이트
- 기타 HTTP 서비스
