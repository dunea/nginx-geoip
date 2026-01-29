构建好了镜像（my-nginx-geoip2:1.28 或你命名的那个），接下来按顺序做这些步骤，就能让你的域名对中国大陆 IP 实现“超时”（return 444，无响应包，客户端看到连接超时）：

### 步骤1：下载 GeoLite2-Country.mmdb 数据库（必须的，免费）
1. 打开浏览器访问：https://www.maxmind.com/en/geolite2/signup （或 https://dev.maxmind.com/geoip/geolite2-free-geolocation-data/）
2. 注册/登录 MaxMind 免费账号（用邮箱注册即可）。
3. 在账号面板生成一个 **License Key**（账户 → Services → License Key → Generate new license key）。
4. 下载 GeoLite2-Country.mmdb：
   - 直接下载链接格式通常是：https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=你的LicenseKey&suffix=tar.gz
   - 下载后解压 zip/tar.gz，里面就有 GeoLite2-Country.mmdb 文件（约 1-2MB）。
   - 把这个文件放到宿主机一个固定目录，比如 `/opt/geoip/GeoLite2-Country.mmdb`（建议新建这个文件夹）。

   **小提示**：数据库每周更新两次（周二/周五），建议每月手动更新一次，或后面我可以给你个简单 cron 脚本自动下载。

### 步骤2：在 Portainer 中创建/更新容器
1. 停止并删除你原来的 Nginx 容器（备份好配置先）。
2. 创建新容器（或编辑栈）：
   - **Image**：用你刚 build 的 `my-nginx-geoip2:1.28`（或你的 tag）。
   - **Ports**：映射 80/443 等，跟原来一样。
   - **Volumes**（关键！）：
     - 挂载你的 nginx 配置目录：宿主机 `/path/to/your/nginx.conf` 或 `/etc/nginx/conf.d/` → 容器 `/etc/nginx/nginx.conf` 或 `/etc/nginx/conf.d/`（根据你原来怎么挂的）。
     - **新增**：宿主机 `/opt/geoip/GeoLite2-Country.mmdb` → 容器 `/usr/share/GeoIP/GeoLite2-Country.mmdb` （权限：只读 ro 更好）。
   - **Network**、**Restart policy** 等保持原样。
   - **Environment**：如果有自定义变量，也带上。
3. 启动容器。

### 步骤3：修改 nginx 配置（核心部分）
在你的 nginx.conf（或 conf.d 里的 server 文件）中添加以下内容。注意位置：

```nginx
# nginx.conf 最开头（http {} 外面，events {} 之前）
load_module modules/ngx_http_geoip2_module.so;

http {
    # 在 http {} 块里添加 geoip2 定义（建议放在 server {} 外面）
    geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
        $geoip2_data_country_code country iso_code;
    }

    # 可选：用 map 更优雅地定义是否阻塞（推荐）
    map $geoip2_data_country_code $block_cn {
        default 0;   # 海外默认不阻塞
        CN      1;   # 中国大陆阻塞
    }

    # 你的 server 块（可以多个）
    server {
        listen 80;
        listen 443 ssl http2;
        server_name example.com www.example.com;

        # 阻塞中国大陆：return 444（最干净，客户端直接超时）
        if ($block_cn = 1) {
            return 444;
        }

        # 正常配置（proxy_pass / root 等）
        location / {
            # 你的后端代理或静态文件
            proxy_pass http://backend;
            # 或 root /var/www/html; 等
        }
    }
}
```

- **为什么用 return 444**：Nginx 特殊码，不发送任何响应头/体，客户端会卡在“连接超时”状态，不会看到 403/504 等错误页，最隐蔽。
- 如果你想测试：临时把 CN 改成 US（你自己的国家），reload 后海外 IP 正常，大陆 IP 超时。

### 步骤4：测试配置 & 重载
1. 在 Portainer 容器 console（或 docker exec -it 你的容器ID sh）里运行：
   ```
   nginx -t
   ```
   - 如果 OK，输出 syntax is ok & test is successful。
   - 如果报错（比如模块没加载、mmdb 文件找不到），检查路径和挂载。
2. 重载配置（不重启容器）：
   ```
   nginx -s reload
   ```
   或在 Portainer 里 Restart 容器（保险）。

### 步骤5：验证效果
- 用海外 IP（或 VPN 切到美国/香港等）访问：正常打开。
- 用中国大陆网络访问（手机热点或朋友测试）：浏览器卡住超时（不是报错页，是连接超时，通常 30s-2min 后断开）。
- 如果没生效：检查日志（docker logs 你的容器），看有没有 geoip2 加载错误。

### 额外建议
- **自动更新数据库**：写个小脚本放宿主机 cron 里，每周跑一次：
  ```bash
  #!/bin/bash
  LICENSE_KEY="你的key"
  curl -s "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=$LICENSE_KEY&suffix=tar.gz" -o /tmp/GeoLite2-Country.tar.gz
  tar -xzf /tmp/GeoLite2-Country.tar.gz -C /tmp
  mv /tmp/GeoLite2-Country_*/GeoLite2-Country.mmdb /opt/geoip/GeoLite2-Country.mmdb
  rm -rf /tmp/GeoLite2-Country* /tmp/*.tar.gz
  docker exec 你的容器ID nginx -s reload   # 可选，重载 nginx
  ```
  加到 crontab：`0 3 * * 2,5 /path/to/script.sh`（周二周五凌晨3点）。

- **安全**：别把 License Key 泄露，脚本里用环境变量存。

完成了这些，你的域名对中国大陆就“隐身”了（超时不响应）。如果测试中出问题（比如 nginx -t 报错、挂载失败），把具体日志贴出来，我继续帮你 debug！