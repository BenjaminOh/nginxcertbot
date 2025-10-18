FROM certbot/certbot

# cron 설치
RUN apk add --no-cache dcron

# 갱신 스크립트 복사
COPY renew.sh /usr/local/bin/renew.sh
RUN chmod +x /usr/local/bin/renew.sh

# cron job 설정
RUN echo "0 12 * * * /usr/local/bin/renew.sh >> /var/log/cron.log 2>&1" | crontab -

# cron 로그 파일 생성
RUN touch /var/log/cron.log

# cron 실행
CMD ["crond", "-f"]
