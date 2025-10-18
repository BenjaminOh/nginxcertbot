# 운영서버 배포 가이드

## 🖥️ 운영서버에서 nginx 인프라 연결하기

### 현재 상황
```bash
# 운영서버에서 실행 중인 컨테이너들
aphennet-nodejs:3001    # Node.js API
aphennet-nextjs:3000    # Next.js 프론트엔드
aphennet-mariadb:3306   # MariaDB
```

### 목표
```bash
# nginx 인프라 추가 후
https://aphennet.likeweb.co.kr      → aphennet-nextjs:3000
https://aphennetapi.likeweb.co.kr   → aphennet-nodejs:3001
```

## 🚀 배포 단계

### 1단계: 프로젝트 업로드
```bash
# 운영서버에 nginx 프로젝트 업로드
scp -r nginx/ user@server:/opt/nginx-infra/
```

### 2단계: 환경 설정
```bash
# 서버에 접속
ssh user@server

# 프로젝트 디렉토리로 이동
cd /opt/nginx-infra

# 환경 변수 설정
cd infrastructure/
cp env.example .env
nano .env

# 설정 내용:
# CERTBOT_DOMAIN=aphennet.likeweb.co.kr,aphennetapi.likeweb.co.kr
# CERTBOT_EMAIL=ohsjwe@gmail.com
# CERTBOT_STAGING=1  # 테스트 후 0으로 변경
```

### 3단계: 기존 서비스 연결
```bash
# 프로젝트 루트로 이동
cd /opt/nginx-infra

# 기존 서비스들을 nginx에 연결
./connect-existing-services.sh
```

### 4단계: 테스트
```bash
# 서비스 상태 확인
docker ps

# nginx 상태 확인
docker compose -f infrastructure/docker-compose.prod.yml ps

# 웹사이트 접속 테스트
curl -k https://aphennet.likeweb.co.kr
curl -k https://aphennetapi.likeweb.co.kr
```

### 5단계: 프로덕션 전환 (테스트 완료 후)
```bash
# 테스트 환경에서 프로덕션으로 전환
./switch-to-production.sh
```

## 🔧 문제 해결

### 포트 충돌 문제
```bash
# 기존 서비스들이 외부 포트를 사용 중인 경우
# nginx는 내부 네트워크로 통신하므로 문제없음
```

### 네트워크 연결 문제
```bash
# 네트워크 상태 확인
docker network ls
docker network inspect web-services-network

# 수동으로 네트워크 연결
docker network connect web-services-network aphennet-nodejs
docker network connect web-services-network aphennet-nextjs
```

### SSL 인증서 문제
```bash
# 인증서 상태 확인
docker compose -f infrastructure/docker-compose.prod.yml exec certbot certbot certificates

# 수동으로 인증서 발급
docker compose -f infrastructure/docker-compose.prod.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email ohsjwe@gmail.com \
    --agree-tos \
    --no-eff-email \
    -d aphennet.likeweb.co.kr \
    -d aphennetapi.likeweb.co.kr
```

## 📋 체크리스트

- [ ] 기존 서비스들이 실행 중인지 확인
- [ ] nginx 프로젝트 업로드 완료
- [ ] 환경 변수 설정 완료
- [ ] connect-existing-services.sh 실행
- [ ] 웹사이트 접속 테스트
- [ ] SSL 인증서 확인
- [ ] 프로덕션 전환 (선택사항)

## 🎯 최종 결과

```bash
# 외부 접속
https://aphennet.likeweb.co.kr      # Next.js 프론트엔드
https://aphennetapi.likeweb.co.kr   # Node.js API

# 내부 통신
nginx → aphennet-nextjs:3000
nginx → aphennet-nodejs:3001
```
