#!/bin/bash

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#运行时APK软件源：使用南京大学 ImmortalWrt Snapshot 镜像
sed -i 's#https://downloads\.immortalwrt\.org/snapshots#https://mirror\.nju\.edu\.cn/immortalwrt/snapshots#g' ./include/version.mk
#video Feed 保留编译可见性，但不生成运行时 APK 软件源
echo "CONFIG_FEED_video=n" >> ./.config

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#USB存储组件
echo "CONFIG_PACKAGE_kmod-usb3=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-audio=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-dwc3=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-dwc3-qcom=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-core=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-storage=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-storage-extras=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-storage-uas=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-fs-vfat=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-fs-exfat=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-fs-ntfs3=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-fs-ext4=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-nls-utf8=y" >> ./.config
echo "CONFIG_PACKAGE_usbutils=y" >> ./.config
echo "CONFIG_PACKAGE_block-mount=y" >> ./.config
echo "CONFIG_PACKAGE_automount=n" >> ./.config
echo "CONFIG_PACKAGE_luci-app-diskman=y" >> ./.config
echo "CONFIG_PACKAGE_hd-idle=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-hd-idle=y" >> ./.config
echo "CONFIG_PACKAGE_nfs-kernel-server=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-nfs=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-filemanager=y" >> ./.config
echo "CONFIG_PACKAGE_usb-modeswitch=n" >> ./.config
echo "CONFIG_PACKAGE_usbmuxd=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=n" >> ./.config
# USB网络/其他驱动保持精简
echo "CONFIG_PACKAGE_kmod-usb-net=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-cdc-eem=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-cdc-ether=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-cdc-subset=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-huawei-cdc-ncm=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-ipheth=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-rndis=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-rtl8150=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-rtl8152=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-asix=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-asix-ax88179=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-net-sierrawireless=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-ohci=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-uhci=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-xhci-hcd=n" >> ./.config

#其他可选UI组件
echo "CONFIG_PACKAGE_luci-app-wolultra=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-statistics=y" >> ./.config

#高通平台调整
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#开启SQM及其基础脚本；NSS 专用脚本资产由 NSS-SQM-618.sh 注入普通 sqm-scripts
	echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
	echo "CONFIG_PACKAGE_sqm-scripts=y" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
	if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
		echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
	else
		echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	fi
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi

fi
