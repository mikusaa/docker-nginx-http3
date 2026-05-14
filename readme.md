## 这是什么？

[![Docker 镜像 CI](https://github.com/mikusaa/docker-nginx-http3/actions/workflows/dockerimage.yml/badge.svg)](https://github.com/mikusaa/docker-nginx-http3/actions/workflows/dockerimage.yml)

这是一个自编译的 NGINX Docker 镜像，目标是提供稳定、较新的 NGINX，并内置 QUIC / HTTP/3、HTTP/2、Brotli、Zstandard、njs、GeoIP2、headers-more、kTLS/sendfile 支持，以及一套偏生产环境的 SSL 默认配置。

镜像发布到 Docker Hub 和 GitHub Container Registry，并提供 `linux/amd64`、`linux/arm64` 两种架构。

## 拉取镜像

从 Docker Hub 拉取：

```bash
docker pull mikusa/nginx-http3:latest
```

从 GitHub Container Registry 拉取：

```bash
docker pull ghcr.io/mikusaa/nginx-http3:latest
```

## 运行用户

容器默认以 `nginx` 用户运行。镜像支持类似 LSIO 的运行时 UID/GID 自定义，可以通过 `PUID` 和 `PGID` 指定容器内 `nginx` 用户的 UID/GID：

```bash
docker run --rm \
  -e PUID=1000 \
  -e PGID=1000 \
  mikusa/nginx-http3:latest
```

如果显式使用 Docker 的 `--user` 参数以非 root 用户启动，入口脚本会跳过 `PUID` / `PGID` 调整，并直接执行传入命令。

## 内置能力

- NGINX 官方模块：SSL、Real IP、HTTP/2、HTTP/3、stream、mail、slice、auth_request、gzip_static、stub_status 等。
- `headers-more-nginx-module`：更灵活地设置、覆盖或清理请求/响应头。
- `ngx_brotli`：支持 Brotli 动态压缩和 `.br` 静态预压缩文件。
- `zstd-nginx-module`：支持 Zstandard 动态压缩和 `.zst` 静态预压缩文件。
- `ngx_http_geoip2_module`：基于 MaxMind GeoIP2 数据库生成客户端 IP 相关变量。
- `njs`：在 NGINX 内使用 JavaScript 扩展请求处理逻辑。
- kTLS/sendfile：编译时启用 OpenSSL kTLS 选项，用于在支持的系统上优化 TLS 传输。

查看 NGINX 编译参数：

```bash
docker run --rm mikusa/nginx-http3 nginx -V
```

查看 njs 版本：

```bash
docker run --rm mikusa/nginx-http3 njs -v
```

## 默认配置

主配置文件为 `/etc/nginx/nginx.conf`，额外提供两个 include 入口：

- `/etc/nginx/main.d/*.conf`：包含在 NGINX main context 中，适合放 `load_module`、`env` 等指令。
- `/etc/nginx/conf.d/*.conf`：包含在 `http` context 中，适合放常规 `server` 配置。

默认 HTTP 配置会：

- 关闭 `server_tokens`。
- 清理 `Server` 和 `X-Powered-By` 响应头。
- 设置基础安全响应头。
- 启用 gzip、Brotli、Zstandard。
- 使用包含 `$http3` 的访问日志格式，便于区分 HTTP/3 请求。

## SSL 配置

镜像内置 `/etc/ssl/dhparam.pem`，构建时来自 Mozilla SSL 配置生成器使用的 `ffdhe2048` 参数。

公共 SSL 配置位于 `/etc/nginx/conf.d/ssl_common.conf`，默认包含：

- TLSv1.2 和 TLSv1.3。
- Mozilla intermediate 风格 cipher 配置。
- `ssl_session_cache`。
- 关闭 `ssl_session_tickets`。
- 开启 OCSP stapling。

在站点配置中可以直接使用：

```nginx
ssl_dhparam /etc/ssl/dhparam.pem;
```

## HTTP/3 示例

HTTP/3 需要同时暴露 TCP 和 UDP 端口，并且两者端口号必须一致。示例：

```nginx
server {
    listen 443 quic reuseport;

    listen 443 ssl;
    http2 on;

    server_name example.com;

    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_early_data on;

    add_header alt-svc 'h3=":443"; ma=86400';
    add_header QUIC-Status $http3;

    location / {
        root /usr/share/nginx/html;
    }
}
```

Docker Compose 示例：

```yaml
services:
  nginx:
    image: mikusa/nginx-http3:latest
    ports:
      - "443:443/tcp"
      - "443:443/udp"
```

## 本地开发和测试

构建本地镜像：

```bash
DOCKER_BUILDKIT=1 docker build . \
  -t mikusa/nginx-http3 \
  --cache-from=ghcr.io/mikusaa/nginx-http3:latest \
  --progress=plain
```

运行仓库内测试配置：

```bash
./run-docker.sh
```

测试默认运行用户：

```bash
docker run --rm mikusa/nginx-http3 whoami
```

期望输出：

```text
nginx
```

测试自定义 UID/GID：

```bash
docker run --rm \
  -e PUID=1000 \
  -e PGID=1001 \
  mikusa/nginx-http3 id
```

期望输出中包含：

```text
uid=1000(nginx) gid=1001(nginx)
```

## GitHub Actions 自动构建

仓库包含两个主要 workflow：

- `.github/workflows/dockerimage.yml`：在 pull request 和 `master` 分支 push 时构建并测试镜像。
- `.github/workflows/push-to-ghcr.yml`：在 GitHub Release 发布或 `master` 分支 push 时，构建并推送多架构镜像。

发布 workflow 会同时推送到：

```text
ghcr.io/mikusaa/nginx-http3
docker.io/mikusa/nginx-http3
```

发布平台为：

```text
linux/amd64
linux/arm64
```

Docker Hub 推送需要在 GitHub 仓库设置中配置以下 secrets：

```text
DOCKERHUB_USERNAME=mikusa
DOCKERHUB_TOKEN=<Docker Hub access token>
```

GitHub Container Registry 使用仓库自带的 `GITHUB_TOKEN`，workflow 已配置 `packages: write` 权限。
