#!/bin/sh

# UUID="00277430-85b5-46e2-a6c9-4fe3da538187"
# APP_NAME="lyz7805-v2ray"
REGION="lax"

if ! command -v flyctl >/dev/null 2>&1; then
    printf '\e[33mCould not resolve command - flyctl. So, install flyctl first.\n\e[0m'
    curl -L https://fly.io/install.sh | FLYCTL_INSTALL=/usr/local sh
fi

if [ -z "${APP_NAME}" ]; then
    printf '\e[31mPlease set APP_NAME first.\n\e[0m' && exit 1
fi

flyctl info --app "${APP_NAME}" >/tmp/${APP_NAME} 2>&1;
if [ "$(cat /tmp/${APP_NAME} | grep -o "Could not resolve")" = "Could not resolve" ]; then
    printf '\e[33mCould not resolve app. Next, create the App.\n\e[0m'
    flyctl apps create "${APP_NAME}" >/dev/null 2>&1;

    flyctl info --app "${APP_NAME}" >/tmp/${APP_NAME} 2>&1;
    if [ "$(cat /tmp/${APP_NAME} | grep -o "Could not resolve")" != "Could not resolve" ]; then
        printf '\e[32mCreate app success.\n\e[0m'
    else
        printf '\e[31mCreate app failed.\n\e[0m' && exit 1
    fi
else
    printf '\e[33mThe app has been created.\n\e[0m'
fi

printf '\e[33mNext, create app config file - fly.toml.\n\e[0m'
cat <<EOF >./fly.toml
app = "$APP_NAME"

kill_signal = "SIGINT"
kill_timeout = 5
processes = []

[env]

[experimental]
  allowed_public_ports = []
  auto_rollback = true

# 移除 [http_service] 部分，因为是 V2Ray 服务器，不需要 HTTP 服务
# [http_service]
#   internal_port = 8080
#   force_https = true
#   auto_stop_machines = false
#   auto_start_machines = true
#   processes = ["app"]

# 移除 [[http_service.checks]] 部分，使用 TCP 检查
# [[http_service.checks]]
#   interval = "5s"
#   grace_period = "10s"
#   timeout = "2s"
#   method = "GET"
#   path = "/healthz"
#   protocol = "http"
#   port = 8080

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 1024 

[[services]]
  internal_port = 10000  #  V2Ray 监听端口
  protocol = "tcp"
  script_checks = []
  http_checks = [] # 移除 http_checks，使用 tcp_checks

  [services.concurrency]
    hard_limit = 50
    soft_limit = 35
    type = "connections"

  # 移除 HTTP/HTTPS 端口配置
  # [[services.ports]]
  #   handlers = ["http"]
  #   port = 80

   [[services.ports]]
     handlers = ["tls"]
     port = 443

  [[services.tcp_checks]]
    interval = "15s"
    timeout = "2s"
    grace_period = "120s" #  启动等待时间可以适当长一些
    restart_limit = 0
EOF
printf '\e[32mCreate app config file success.\n\e[0m'
printf '\e[33mNext, set app secrets and regions.\n\e[0m'

flyctl secrets set UUID="${UUID}"
flyctl regions set ${REGION}
printf '\e[32mApp secrets and regions set success. Next, deploy the app.\n\e[0m'
flyctl deploy --detach
# flyctl status --app ${APP_NAME}
