FROM nginx:1.28.0-alpine

# 安装 GeoIP2 模块 + 运行时库
RUN apk add --no-cache nginx-mod-http-geoip2 libmaxminddb

# 创建数据库目录
RUN mkdir -p /usr/share/GeoIP