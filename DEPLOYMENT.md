# nginx + certbot 웹서비스 배포 가이드

## 개요
이 프로젝트는 nginx를 웹서버로, certbot을 SSL 인증서 관리자로 사용하여 웹서비스를 운영하는 구성입니다.

## 아키텍처 설명

### nginx의 역할 (웹서버)
- **웹서버**: 정적 파일 제공, 리버스 프록시 역할
- **SSL 터미네이션**: HTTPS 인증서 처리
- **로드 밸런싱**: 여러 백엔드 서버로 요청 분산
- **WAS가 아님**: 동적 애플리케이션 실행은 백엔드 서버(Next.js, Node.js)가 담당

### certbot의 역할
- **Let's Encrypt 인증서 발급**: 무료 SSL 인증서
- **자동 갱신**: cron을 통한 인증서 갱신
- **웹루트 인증**: 도메인 소유권 확인

## 사전 준비사항

### 1. 도메인 설정
- `aphennet.likeweb.co.kr` (프론트엔드)
- `aphennetapi.likeweb.co.kr` (API)
- DNS A 레코드가 서버 IP를 가리키도록 설정

### 2. 환경 변수 설정
```bash
# env.example을 .env로 복사하고 실제 값으로 수정
cp env.example .env
```

`.env` 파일에서 다음 값들을 수정:
- `CERTBOT_DOMAIN`: 실제 도메인명
- `CERTBOT_EMAIL`: 실제 이메일 주소
- `DATABASE_URL`: 실제 데이터베이스 연결 정보
- `JWT_SECRET`: 실제 JWT 시크릿 키

## 배포 단계

### 1. 초기 SSL 인증서 발급
```bash
# 인증서 발급 스크립트 실행
chmod +x certbot/init-letsencrypt.sh
./certbot/init-letsencrypt.sh
```

### 2. 서비스 시작
```bash
# 모든 서비스 시작
docker compose -f docker-compose.prod.yml up -d
```

### 3. 서비스 상태 확인
```bash
# 컨테이너 상태 확인
docker compose -f docker-compose.prod.yml ps

# nginx 로그 확인
docker compose -f docker-compose.prod.yml logs nginx

# SSL 인증서 확인
docker compose -f docker-compose.prod.yml exec nginx nginx -t
```

## 서비스 관리

### 서비스 재시작
```bash
# 특정 서비스 재시작
docker compose -f docker-compose.prod.yml restart nginx

# 모든 서비스 재시작
docker compose -f docker-compose.prod.yml restart
```

### SSL 인증서 갱신
```bash
# 수동 갱신
docker compose -f docker-compose.prod.yml run --rm certbot renew

# 자동 갱신 (cron으로 설정됨)
# 매일 오후 12시에 자동 실행
```

### 로그 확인
```bash
# nginx 로그
docker compose -f docker-compose.prod.yml logs -f nginx

# certbot 로그
docker compose -f docker-compose.prod.yml logs -f certbot

# 모든 서비스 로그
docker compose -f docker-compose.prod.yml logs -f
```

## 트러블슈팅

### SSL 인증서 발급 실패
1. 도메인이 서버 IP를 올바르게 가리키는지 확인
2. 방화벽에서 80, 443 포트가 열려있는지 확인
3. `.env` 파일의 도메인과 이메일 설정 확인

### nginx 설정 오류
```bash
# nginx 설정 문법 검사
docker compose -f docker-compose.prod.yml exec nginx nginx -t

# nginx 설정 다시 로드
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

### 백엔드 서비스 연결 실패
1. 백엔드 서비스가 실행 중인지 확인
2. 네트워크 설정 확인
3. 포트 매핑 확인

## 보안 고려사항

1. **환경 변수 보안**: `.env` 파일을 `.gitignore`에 추가
2. **SSL 설정**: 강력한 암호화 설정 사용
3. **방화벽**: 필요한 포트만 열기
4. **정기 업데이트**: 컨테이너 이미지 정기 업데이트

## 모니터링

### 헬스체크
- API 헬스체크: `https://aphennetapi.likeweb.co.kr/health`
- 프론트엔드: `https://aphennet.likeweb.co.kr`

### 로그 모니터링
```bash
# 실시간 로그 모니터링
docker compose -f docker-compose.prod.yml logs -f --tail=100
```

## 백업 및 복구

### SSL 인증서 백업
```bash
# 인증서 백업
tar -czf certbot-backup.tar.gz certbot/conf/
```

### 설정 파일 백업
```bash
# nginx 설정 백업
cp nginx/nginx.conf nginx/nginx.conf.backup
```

이 가이드를 따라하면 nginx와 certbot을 이용한 안전하고 확장 가능한 웹서비스를 운영할 수 있습니다.
