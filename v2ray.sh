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

echo "--------------------------------"
echo "Fly App Name: ${FLY_APP_NAME}"
echo "Fly App Region: ${FLY_REGION}"
echo "V2Ray UUID: ${UUID}"  #  <--  输出生成的 UUID
echo "--------------------------------"

#  开始修改 config.json  (新增配置修改部分)
echo "修改 config.json ..."


CONFIG_FILE="${INSTALL_PATH}/config.json"

#  替换 inbounds 部分为 vmess 服务器配置
sed -i "s#\"inbounds\": \[.*\]#\"inbounds\": [\n      {\n        \"port\": 10000,\n        \"listen\": \"0.0.0.0\",\n        \"protocol\": \"vmess\",\n        \"settings\": {\n          \"clients\": [\n            {\n              \"id\": \"${UUID}\",\n              \"alterId\": 0,\n              \"security\": \"auto\"\n            }\n          ]\n        }\n      }\n    ]#g" "${CONFIG_FILE}"

#  简化 outbounds 部分 (只保留 freedom, 移除 socks, 可选保留 blackhole)
sed -i "/},{\"protocol\": \"socks\".*},{\"protocol\": \"blackhole\"/d" "${CONFIG_FILE}"  #  移除 socks 和 blackhole 出站 (如果原配置是这个顺序)
sed -i "/},{\"protocol\": \"socks\".*}/d" "${CONFIG_FILE}" # 移除 socks 出站 (如果 blackhole 不存在或顺序不同)
sed -i "/\"defaultOutboundTag\": \".*\"/c\"defaultOutboundTag\": \"freedom\"" "${CONFIG_FILE}" # 设置默认出站为 freedom

#  简化 routing 部分 (简化规则，例如只保留阻止内网 IP 的规则，这里省略，可以根据需要添加更多 sed 命令修改 routing 部分)
#  ...  可以根据需要添加更多 sed 命令来修改 routing 部分  ...

echo "config.json 修改完成"

# mv CONFIG_FILE "${INSTALL_PATH}"

# Run v2ray (保持不变)
v2ray run


