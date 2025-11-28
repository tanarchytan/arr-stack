FROM alpine:3.19
RUN apk add --no-cache docker-cli
COPY watchdog.sh /watchdog.sh
ENTRYPOINT ["sh", "/watchdog.sh"]
