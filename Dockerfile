FROM alpine:latest

RUN apk update && apk add --no-cache curl wget unzip
RUN apk update && apk add jq

# 下载 V2Ray
RUN wget -q https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip -O v2ray.zip && \
    unzip v2ray.zip && \
    mv v2ray /usr/bin/v2ray && \
    rm v2ray.zip

# 创建 V2Ray 配置目录
RUN mkdir -p /etc/v2ray


# 复制 v2ray.sh 启动脚本
COPY v2ray.sh /

# 设置启动脚本执行权限
RUN chmod +x /v2ray.sh

# 暴露端口 (根据 config.json 中服务器监听端口修改，这里假设是 10000)
EXPOSE 10000  

# 定义启动命令
CMD ["/v2ray.sh"]
