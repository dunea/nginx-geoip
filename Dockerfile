FROM nginx:1.28.0-alpine AS builder

RUN apk add --no-cache git gcc musl-dev pcre-dev zlib-dev linux-headers make libmaxminddb-dev

RUN git clone --depth=1 https://github.com/leev/ngx_http_geoip2_module.git /tmp/ngx_http_geoip2_module

RUN wget https://nginx.org/download/nginx-1.28.0.tar.gz -O /tmp/nginx.tar.gz \
    && tar -zx -C /tmp -f /tmp/nginx.tar.gz \
    && cd /tmp/nginx-1.28.0 \
    && ./configure --with-compat --add-dynamic-module=/tmp/ngx_http_geoip2_module \
    && make modules -j$(nproc) \
    && mkdir -p /modules \
    && cp objs/ngx_http_geoip2_module.so /modules/

FROM nginx:1.28.0-alpine

COPY --from=builder /modules/ngx_http_geoip2_module.so /usr/lib/nginx/modules/ngx_http_geoip2_module.so

RUN apk add --no-cache libmaxminddb

RUN mkdir -p /usr/share/GeoIP