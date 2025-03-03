FROM alpine:latest

RUN apk update && apk add --no-cache curl wget unzip

# 下载 V2Ray
RUN wget -q https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip -O v2ray.zip && \
    unzip v2ray.zip && \
    mv v2ray /usr/bin/v2ray && \
    mv v2ctl /usr/bin/v2ctl && \
    chmod +x /usr/bin/v2ray /usr/bin/v2ctl && \
    rm v2ray.zip

# 创建 V2Ray 配置目录
RUN mkdir -p /etc/v2ray

# 复制配置文件 (取消注释并确保 config.json 文件与 Dockerfile 在同一目录下)
COPY config.json /etc/v2ray/config.json

# 复制 v2ray.sh 启动脚本
COPY v2ray.sh /

# 设置启动脚本执行权限
RUN chmod +x /v2ray.sh

# 暴露端口 (根据 config.json 中服务器监听端口修改，这里假设是 10000)
EXPOSE 10000  #  <--  修改为服务器监听端口

# 定义启动命令
CMD ["/v2ray.sh"]
