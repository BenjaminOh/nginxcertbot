# WordPress 블로그 서비스 템플릿

## 사용법
이 템플릿을 사용하여 WordPress 블로그를 nginx 인프라에 추가할 수 있습니다.

## 필요한 정보
- 서비스명 (예: my-blog)
- 도메인 (예: blog.mysite.com)
- 포트 (기본값: 80)

## 생성되는 파일들
1. `nginx/conf.d/servers/SERVICE_NAME.conf` - nginx 서버 설정
2. `nginx/conf.d/upstreams.conf` 업데이트 - 업스트림 서버 추가

## 사용 예시
```bash
./services/scripts/add-service.sh wordpress my-blog blog.mysite.com 80
```

## nginx 서버 설정 템플릿

```nginx
# HTTP 서버 블록 - {{DOMAIN}}
server {
    listen 80;
    server_name {{DOMAIN}};
    
    # Let's Encrypt 인증서 발급을 위한 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # HTTP를 HTTPS로 리다이렉트
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS 서버 블록 - {{DOMAIN}}
server {
    listen 443 ssl;
    server_name {{DOMAIN}};

    # SSL 인증서 설정
    ssl_certificate /etc/letsencrypt/live/{{DOMAIN}}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{{DOMAIN}}/privkey.pem;
    
    # SSL 보안 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # WordPress 서비스로 프록시
    location / {
        proxy_pass http://{{SERVICE_NAME}}/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WordPress 특별 설정
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
    }
}
```

## 업스트림 설정 템플릿

```nginx
upstream {{SERVICE_NAME}} {
    server {{SERVICE_NAME}}:{{PORT}};
}
```
