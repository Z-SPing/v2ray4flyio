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
DGST_FILE="${V2RAY_ZIP}.dgst"
DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/download/${TAG}/${V2RAY_ZIP}"

echo "下载: ${V2RAY_ZIP} 和校验文件..."
wget -O "${DOWNLOAD_PATH}/v2ray.zip" "${DOWNLOAD_URL}" || (echo "下载失败!" && exit 1)
wget -O "${DOWNLOAD_PATH}/v2ray.zip.dgst" "${DOWNLOAD_URL}.dgst" || (echo "下载校验文件失败!" && exit 1)

# 校验文件完整性
echo "校验文件完整性..."
LOCAL_SHA512=$(openssl dgst -sha512 "${DOWNLOAD_PATH}/v2ray.zip" | awk '{print $2}')
REMOTE_SHA512=$(cat "${DOWNLOAD_PATH}/v2ray.zip.dgst" | grep 'SHA512' | cut -d' ' -f2)

[ "${LOCAL_SHA512}" != "${REMOTE_SHA512}" ] && echo "校验失败! 文件可能被篡改" && exit 1
echo "校验通过"

# 解压并安装
echo "解压文件..."
unzip -j "${DOWNLOAD_PATH}/v2ray.zip" -d "${DOWNLOAD_PATH}/extracted" # -j 忽略子目录，直接解压到 extracted
cd "${DOWNLOAD_PATH}/extracted" || exit

# 移动文件到系统目录
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
