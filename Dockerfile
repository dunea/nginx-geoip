FROM nginx:1.28-alpine

# 安装现成 GeoIP2 模块包 + 运行时库
RUN apk add --no-cache nginx-mod-http-geoip2 libmaxminddb

# 创建数据库目录
RUN mkdir -p /usr/share/GeoIP

# 可选：如果想预加载模块（但你 conf 已有 load_module，也行）