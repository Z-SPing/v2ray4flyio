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
echo "安装到系统路径..."
mv v2ray config.json vpoint_socks_vmess.json vpoint_vmess_freedom.json systemd "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}/v2ray"
chmod +x "${INSTALL_PATH}/config.json"
chmod +x "${INSTALL_PATH}/vpoint_socks_vmess.json"
chmod +x "${INSTALL_PATH}/vpoint_vmess_freedom.json"


mkdir -p "${DATA_PATH}"
mv geosite.dat geoip.dat "${DATA_PATH}"



# 清理临时文件
echo "清理临时文件..."
rm -rf "${DOWNLOAD_PATH}"
echo "Install done"

echo "--------------------------------"
echo "Fly App Name: ${FLY_APP_NAME}"
echo "Fly App Region: ${FLY_REGION}"
echo "V2Ray UUID: ${UUID}"
echo "--------------------------------"

#  开始修改 config.json (修改为 服务器端 配置)
echo "修改 config.json 为服务器端配置 ..."
CONFIG_FILE="${INSTALL_PATH}/config.json"

#  配置 inbounds 部分为 VMess 服务器监听
server_inbounds_config='
"inbounds": [
  {
    "port": 10000,
    "listen": "0.0.0.0",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "${UUID}",
          "alterId": 0,
          "security": "auto"
        }
      ]
    }
  }
]
'
sed -i "s/\"inbounds\": \[.*\]/\"inbounds\": [${server_inbounds_config}]/g" "${CONFIG_FILE}"


#  配置 outbounds 部分为 freedom (服务器端只需要 freedom 出站)
server_outbounds_config='
"outbounds": [
  {
    "tag": "freedom",
    "protocol": "freedom",
    "settings": {}
  }
],
"defaultOutboundTag": "freedom"
'
sed -i "/\"outbounds\": \[/,/\"defaultOutboundTag\": \".*\"/c\\${server_outbounds_config}" "${CONFIG_FILE}"


#  简化 routing 部分 (服务器端路由规则可以更简单)
server_routing_config='
"routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "outboundTag": "freedom"
      }
    ]
  }
'
sed -i "/\"routing\": \{/,/\}/c\\${server_routing_config}" "${CONFIG_FILE}"


echo "config.json 服务器端配置完成"


# Run v2ray (保持不变)
v2ray run
