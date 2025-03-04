#!/bin/sh

# UUID="00277430-85b5-46e2-a6c9-4fe3da538187"
# APP_NAME="lyz7805-v2ray"

REGION="lax"
VOLUME_NAME="swap_volume"  # 定义 Volume 名称
VOLUME_SIZE_GB=3        # 定义 Volume 大小 (GB)

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

[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_mb = 256

[[services]]
  internal_port = 10000  #  V2Ray 监听端口
  protocol = "tcp"
  script_checks = []
  http_checks = [] # 移除 http_checks，使用 tcp_checks

  [services.concurrency]
    hard_limit = 50
    soft_limit = 35
    type = "connections"

   [[services.ports]]
     handlers = ["tls"]
     port = 443

  [[services.tcp_checks]]
    interval = "15s"
    timeout = "2s"
    grace_period = "120s" #  启动等待时间可以适当长一些
    restart_limit = 0
[[mounts]]  # Added mounts section for volume
    source= "${VOLUME_NAME}"  # 使用变量
    destination="/mnt/volume"

EOF
printf '\e[32mCreate app config file success.\n\e[0m'
printf '\e[33mNext, set app secrets and regions.\n\e[0m'

flyctl secrets set UUID="${UUID}"
fly scale count 1 -r "${REGION}" -y
flyctl regions set ${REGION} # 放在 scale 之后可能更清晰

printf '\e[33mNext, create volume before deploy.\n\e[0m'  #  明确提示创建 volume 步骤

#  !!!  提前创建 Volume，放在 deploy 之前  !!!
printf '\e[33mCreating volume "${VOLUME_NAME}"...\n\e[0m'
flyctl volumes create "${VOLUME_NAME}" -a "${APP_NAME}" -r "${REGION}" -s "${VOLUME_SIZE_GB}" -y
if [ $? -ne 0 ]; then
    printf '\e[31mFailed to create volume "${VOLUME_NAME}". Please check errors above and ensure region is set correctly.\n\e[0m' && exit 1
fi
printf '\e[32mVolume "${VOLUME_NAME}" created successfully.\n\e[0m'


printf '\e[32mApp secrets, regions and volume set success. Next, deploy the app.\n\e[0m'
flyctl deploy --detach  #  !!!  添加了 flyctl deploy --detach 命令 !!!

printf '\e[33mWaiting for deployment to complete before setting up swap...\n\e[0m'
sleep 30 #  !!! 添加 sleep 等待时间 !!!

printf '\e[33mNext, setup swap space on volume (step by step)...\n\e[0m' # 提示分步骤设置 swap

#  !!!  分步骤执行 Swap 配置命令，简化 SSH 命令  !!!
flyctl ssh console -a "${APP_NAME}" -C "sudo mkdir -p /mnt/volume"  # 确保 /mnt/volume 目录存在 (虽然应该已经存在，以防万一)
flyctl ssh console -a "${APP_NAME}" -C "sudo fallocate -l 1G /mnt/volume/swapfile"
flyctl ssh console -a "${APP_NAME}" -C "sudo chmod 600 /mnt/volume/swapfile"
flyctl ssh console -a "${APP_NAME}" -C "sudo mkswap /mnt/volume/swapfile"
flyctl ssh console -a "${APP_NAME}" -C "sudo swapon /mnt/volume/swapfile"
flyctl ssh console -a "${APP_NAME}" -C "swapon -s" # 验证 Swap 是否启用
flyctl ssh console -a "${APP_NAME}" -C "echo 'Swap space created and enabled successfully!'"


printf '\e[32mDeployment and Swap space configuration complete.\n\e[0m'
