#!/bin/sh

# UUID="00277430-85b5-46e2-a6c9-4fe3da538187"
# APP_NAME="lyz7805-v2ray"

REGION="lax"
VOLUME_NAME="swap_volume"
VOLUME_SIZE_GB=3
MAX_CPUS=2
MAX_VOLUMES=1

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
  cpus = ${MAX_CPUS} # 设置最大 CPU 数量为 2
  memory_mb = 1024

[[services]]
  internal_port = 10000  #  V2Ray 监听端口
  protocol = "tcp"
  script_checks = []
  http_checks = []

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
    grace_period = "120s"
    restart_limit = 0

[[mounts]] # 配置 Volume 挂载
    source= "${VOLUME_NAME}"
    destination="/mnt/volume"

EOF
printf '\e[32mCreate app config file success.\n\e[0m'
printf '\e[33mNext, set app secrets and regions.\n\e[0m'

flyctl secrets set UUID="${UUID}"

# 使用 fly scale count 命令设置 region
printf '\e[33mSetting region and scaling app...\n\e[0m'
fly scale count 1 -r "${REGION}" -y
if [ $? -ne 0 ]; then
    printf '\e[31mFailed to set region using fly scale count. Please check errors above.\n\e[0m' && exit 1
fi
printf '\e[32mRegion set successfully.\n\e[0m'


printf '\e[33mNext, create volume before deploy.\n\e[0m'
flyctl volumes create "${VOLUME_NAME}" -a "${APP_NAME}" -r "${REGION}" -s "${VOLUME_SIZE_GB}" -y
if [ $? -ne 0 ]; then
    printf '\e[31mFailed to create volume "${VOLUME_NAME}". Please check errors above or if volume already exists.\n\e[0m'
    #  不直接 exit，因为 volume 可能已经存在，后面会检查数量
else
    printf '\e[32mVolume "${VOLUME_NAME}" created successfully.\n\e[0m'
fi


printf '\e[32mApp secrets, region and volume setup done. Next, deploy the app.\n\e[0m'
flyctl deploy --detach

printf '\e[33mWaiting for deployment to complete before checking resources...\n\e[0m'
sleep 30 #  Wait for deployment to start

# ---------- Volume 数量限制检查和调整 ----------
printf '\e[33mChecking Volume count...\n\e[0m'
volume_list_json=$(flyctl volumes list --app "${APP_NAME}" --json)
swap_volume_ids=()
volume_count=0

if [ -n "${volume_list_json}" ]; then
    while IFS= read -r volume; do
        volume_name=$(echo "$volume" | jq -r '.Name')
        volume_id=$(echo "$volume" | jq -r '.ID')
        if [ "${volume_name}" = "${VOLUME_NAME}" ]; then
            swap_volume_ids+=("${volume_id}")
            volume_count=$((volume_count + 1))
        fi
    done < <(echo "${volume_list_json}" | jq -c '.[]')

    if [ "${volume_count}" -gt "${MAX_VOLUMES}" ]; then
        printf '\e[33mFound ${volume_count} volumes with name "${VOLUME_NAME}", exceeding limit of ${MAX_VOLUMES}. Deleting лишние volumes.\n\e[0m'
        for ((i=1; i<${volume_count}; i++)); do
            volume_to_delete="${swap_volume_ids[$i]}"
            printf '\e[33mDeleting лишний volume ID: ${volume_to_delete}...\n\e[0m'
            flyctl volumes delete "${volume_to_delete}" -a "${APP_NAME}" -y
            if [ $? -ne 0 ]; then
                printf '\e[31mFailed to delete volume ID: ${volume_to_delete}. Please check errors above.\n\e[0m'
            else
                printf '\e[32mDeleted volume ID: ${volume_to_delete} successfully.\n\e[0m'
            fi
        done
        printf '\e[32m лишние volumes deleted. Volume count adjusted to ${MAX_VOLUMES}.\n\e[0m'
    else
        printf '\e[32mVolume count is within limit (${volume_count} <= ${MAX_VOLUMES}). No volume deletion needed.\n\e[0m'
    fi
else
    printf '\e[31mFailed to retrieve volume list. Skipping volume limit check.\n\e[0m'
fi


# ---------- CPU 数量限制检查和调整 ----------
printf '\e[33mChecking CPU count...\n\e[0m'
current_cpu_count=$(flyctl status --app "${APP_NAME}" --json | jq '.app.machine_config.cpus')
if [ -n "${current_cpu_count}" ]; then
    current_cpu_count=$(echo "${current_cpu_count}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ "${current_cpu_count}" -gt "${MAX_CPUS}" ]; then
        printf '\e[33mCurrent CPU count is ${current_cpu_count}, exceeding limit of ${MAX_CPUS}. Scaling down to ${MAX_CPUS} CPUs.\n\e[0m'
        flyctl scale cpu "${MAX_CPUS}" -a "${APP_NAME}" -y
        if [ $? -eq 0 ]; then
            printf '\e[32mCPU count scaled down to ${MAX_CPUS} successfully.\n\e[0m'
        else
            printf '\e[31mFailed to scale down CPU count. Please check errors above.\n\e[0m'
        fi
    else
        printf '\e[32mCPU count is within limit (${current_cpu_count} <= ${MAX_CPUS}). No scaling needed.\n\e[0m'
    fi
else
    printf '\e[31mFailed to retrieve current CPU count. Skipping CPU limit check.\n\e[0m'
fi


printf '\e[33mNext, setup swap space on volume (step by step)...\n\e[0m'

flyctl ssh console -a "${APP_NAME}" -C "sudo mkdir -p /mnt/volume"
flyctl ssh console -a "${APP_NAME}" -C "sudo fallocate -l 1G /mnt/volume/swapfile"
flyctl ssh console -a "${APP_NAME}" -C "sudo chmod 600 /mnt/volume/swapfile"
flyctl ssh console -a "${APP_NAME}" -C "sudo mkswap /mnt/volume/swapfile"
flyctl ssh console -a "${APP_NAME}" -C "sudo swapon /mnt/volume/swapfile"
flyctl ssh console -a "${APP_NAME}" -C "swapon -s"
flyctl ssh console -a "${APP_NAME}" -C "echo 'Swap space created and enabled successfully!'"


printf '\e[32mDeployment and resource configuration complete.\n\e[0m'
