FROM nginx:1.28.0-alpine

# 先添加 Alpine edge/community 仓库（确保最新模块）
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories \
    && apk update \
    && apk add --no-cache nginx-mod-http-geoip2 libmaxminddb

RUN mkdir -p /usr/share/GeoIP