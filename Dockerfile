FROM alpine:latest

WORKDIR /root
COPY v2ray.sh /root/v2ray.sh

RUN set -ex \
    && apk add --no-cache tzdata openssl ca-certificates \
    && mkdir -p /etc/v2ray /usr/local/share/v2ray /var/log/v2ray \
    && chmod +x /root/v2ray.sh

RUN setcap -r /usr/bin/v2ray
USER nobody:nogroup

CMD [ "/root/v2ray.sh" ]
