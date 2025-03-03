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
V2RAY_TAR="v2ray-linux-${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/download/${TAG}/${V2RAY_TAR}"

echo "Downloading: ${V2RAY_TAR}..."
wget -O "${DOWNLOAD_PATH}/${V2RAY_TAR}" "${DOWNLOAD_URL}" || (echo "Download failed!" && exit 1)

# Extract and install
echo "Extracting..."
tar -xzf "${DOWNLOAD_PATH}/${V2RAY_TAR}" -C "${DOWNLOAD_PATH}"

cd "${DOWNLOAD_PATH}" || exit

# Move files to system directory
echo "安装到系统路径..."
mv v2ray v2ctl "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}/v2ray" "${INSTALL_PATH}/v2ctl"
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

# Run v2ray
/usr/bin/v2ray -config /etc/v2ray/config.json
