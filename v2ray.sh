#!/bin/sh

# Set ARG
set -e

# 配置参数
ARCH="64"
DOWNLOAD_PATH="/tmp/v2ray"
INSTALL_PATH="/usr/bin"
DATA_PATH="/usr/local/share/v2ray"

mkdir -p ${DOWNLOAD_PATH}
cd ${DOWNLOAD_PATH} || exit

# 获取最新版本标签
TAG=$(wget -qO- --no-check-certificate https://api.github.com/repos/v2fly/v2ray-core/releases/latest | grep 'tag_name' | cut -d\" -f4)
[ -z "${TAG}" ] && echo "Error: 获取v2ray版本失败" && exit 1
echo "最新版本: ${TAG}"

# 下载文件
V2RAY_ZIP="v2ray-linux-${ARCH}.zip"
DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/download/${TAG}/${V2RAY_ZIP}"
DGST_URL="${DOWNLOAD_URL}.dgst"

echo "Downloading: ${V2RAY_ZIP} and checksum file..."
wget -O "${DOWNLOAD_PATH}/${V2RAY_ZIP}" "${DOWNLOAD_URL}" || (echo "Download failed!" && exit 1)
wget -O "${DOWNLOAD_PATH}/${V2RAY_ZIP}.dgst" "${DGST_URL}" || (echo "Download checksum failed!" && exit 1)


# Verify checksum
echo "Verifying checksum..."
LOCAL_HASH=$(sha512sum "${DOWNLOAD_PATH}/${V2RAY_ZIP}" | awk '{print $1}')
REMOTE_HASH=$(grep -i '^SHA2-512=' "${DOWNLOAD_PATH}/${V2RAY_ZIP}.dgst" | awk -F'= ' '{print $2}')

if [ "${LOCAL_HASH}" = "${REMOTE_HASH}" ]; then
  echo "Checksum verified successfully ✅"
else
  echo "Checksum verification failed ❌ File may be corrupted."
  exit 1
fi

# Extract and install
echo "Extracting..."
unzip -o "${DOWNLOAD_PATH}/${V2RAY_ZIP}" -d "${DOWNLOAD_PATH}"
cd "${DOWNLOAD_PATH}" || exit

# Move files to system directory
echo "安装到系统路径...."
mv v2ray config.json vpoint_socks_vmess.json vpoint_vmess_freedom.json systemd "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}/v2ray"
chmod +x "${INSTALL_PATH}/config.json"
chmod +x "${INSTALL_PATH}/vpoint_socks_vmess.json"
chmod +x "${INSTALL_PATH}/vpoint_vmess_freedom.json"

mkdir -p "${DATA_PATH}"
mv geosite.dat geoip.dat "${DATA_PATH}"

echo "--------------------------------"
echo "Fly App Name: ${FLY_APP_NAME} v3"
echo "Fly App Region: ${FLY_REGION}"
echo "V2Ray UUID: ${UUID}"
echo "--------------------------------"

#  开始修改 config.json (使用 jq 修改为 服务器端 配置)
echo "修改 config.json 为服务器端配置 (使用 jq) ..."
CONFIG_FILE="${INSTALL_PATH}/config.json"



# 新增：移除 config.json 文件中的注释行
echo "移除 config.json 文件中的注释行..."
TEMP_CONFIG_FILE="${CONFIG_FILE}.temp"
sed '/^\s*\/\//d' "${CONFIG_FILE}" > "${TEMP_CONFIG_FILE}"
mv "${TEMP_CONFIG_FILE}" "${CONFIG_FILE}"
echo "注释行已移除"



# 配置 inbounds 部分
jq ".inbounds = [{\"port\": 10000, \"listen\": \"0.0.0.0\", \"protocol\": \"vmess\", \"settings\": {\"clients\": [{\"id\": \"${UUID}\", \"alterId\": 0, \"security\": \"none\"}]}}]" "${CONFIG_FILE}" > temp.json && mv temp.json "${CONFIG_FILE}"

# 配置 outbounds 部分
jq ".outbounds = [{\"tag\": \"freedom\", \"protocol\": \"freedom\", \"settings\": {}}]" "${CONFIG_FILE}" > temp.json && mv temp.json "${CONFIG_FILE}"
jq ".defaultOutboundTag = \"freedom\"" "${CONFIG_FILE}" > temp.json && mv temp.json "${CONFIG_FILE}"

# 配置 routing 部分
jq ".routing = {\"domainStrategy\": \"AsIs\", \"rules\": [{\"type\": \"field\", \"domain\": [\"*\"], \"outboundTag\": \"freedom\"}]}" "${CONFIG_FILE}" > temp.json && mv temp.json "${CONFIG_FILE}"

echo "config.json 修改为服务器端配置完成 (修改了routing)"

echo "config.json 文件内容 (jq 执行后后后后后):"
cat "${CONFIG_FILE}"  # 打印 config.json 文件内容

# 清理临时文件
echo "清理临时文件..."
rm -rf "${DOWNLOAD_PATH}"  
echo "Install done"

# Run v2ray 
v2ray run

sleep 5

echo "--- Top 5 Memory Consuming Processes after V2Ray Startup ---"

# 使用 ps 命令获取内存占用前 5 的进程
ps -o pid,user,%mem,rss,vsz,command --sort=-%mem | head -n 5

echo "---------------------------------------------------------"
