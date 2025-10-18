FROM certbot/certbot

# 갱신 스크립트 복사
COPY renew.sh /usr/local/bin/renew.sh
RUN chmod +x /usr/local/bin/renew.sh

# 간단한 대기 명령어로 컨테이너 유지
CMD ["tail", "-f", "/dev/null"]
