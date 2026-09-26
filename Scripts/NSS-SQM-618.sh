#!/bin/bash

# ZN-M2 / IPQ6018 / Linux 6.18 NSS SQM first implementation.
# Sources are pinned to exact Git commits for reproducibility:
#   Kernel qdisc glue: coolsnowwolf/lede master @ 241650a12c1121c76ba6e82567f3cbd81e368d3d
#   iproute2 NSS qdisc/mirred: JuliusBairaktaris/openwrt-nss-edma
#       nss-edma-rework @ 6ba07f713e9dfed09b763f9ef741c55758d6bf9f
#   SQM script: qosmio/sqm-scripts-nss main @ 4b4ed8639229be5e70cf94b73cdf7dbc09e66d5d
#
# Do not change .config here. The existing luci-app-sqm, qca-nss-drv-qdisc
# and qca-nss-drv-igs selections are intentionally reused.

apply_nss_sqm_618() {
	local WRT_ROOT="${GITHUB_WORKSPACE}/wrt"
	local KERNEL_PATCH_DIR="${WRT_ROOT}/target/linux/qualcommax/patches-6.18"
	local IPROUTE_PATCH_DIR="${WRT_ROOT}/package/network/utils/iproute2/patches"
	local SQM_FEED_MAKEFILE="${WRT_ROOT}/feeds/packages/net/sqm-scripts/Makefile"
	local SQM_ASSET_DIR="${WRT_ROOT}/package/zn-m2-nss-sqm-assets"

	local LEDE_REF="241650a12c1121c76ba6e82567f3cbd81e368d3d"
	local JULIUS_REF="6ba07f713e9dfed09b763f9ef741c55758d6bf9f"
	local QOSMIO_REF="4b4ed8639229be5e70cf94b73cdf7dbc09e66d5d"

	local LEDE_RAW="https://raw.githubusercontent.com/coolsnowwolf/lede/${LEDE_REF}"
	local JULIUS_RAW="https://raw.githubusercontent.com/JuliusBairaktaris/openwrt-nss-edma/${JULIUS_REF}"
	local QOSMIO_RAW="https://raw.githubusercontent.com/qosmio/sqm-scripts-nss/${QOSMIO_REF}"

	echo " "
	echo "========== NSS SQM 6.18 integration =========="

	if [ ! -d "${WRT_ROOT}" ]; then
		echo "ERROR: WRT root not found: ${WRT_ROOT}"
		return 1
	fi

	if [ ! -f "${WRT_ROOT}/target/linux/qualcommax/Makefile" ]; then
		echo "ERROR: qualcommax target Makefile not found!"
		return 1
	fi

	if ! grep -Eq '^[[:space:]]*KERNEL_PATCHVER:=6\.18[[:space:]]*$' "${WRT_ROOT}/target/linux/qualcommax/Makefile"; then
		echo "ERROR: NSS SQM 6.18 integration requires qualcommax KERNEL_PATCHVER=6.18."
		return 1
	fi

	local IPROUTE_MAKEFILE="${WRT_ROOT}/package/network/utils/iproute2/Makefile"
	if [ ! -f "${IPROUTE_MAKEFILE}" ] || ! grep -Eq '^PKG_VERSION:=6\.18\.0$' "${IPROUTE_MAKEFILE}"; then
		echo "ERROR: iproute2 6.18.0 was not found; refusing to apply the 6.18 NSS tc patch."
		return 1
	fi

	if [ ! -f "${SQM_FEED_MAKEFILE}" ]; then
		echo "ERROR: sqm-scripts feed Makefile not found: ${SQM_FEED_MAKEFILE}"
		return 1
	fi

	mkdir -p "${KERNEL_PATCH_DIR}" "${IPROUTE_PATCH_DIR}" "${SQM_ASSET_DIR}"

	fetch() {
		local URL="$1"
		local DEST="$2"

		curl -fL --retry 3 --connect-timeout 15 --max-time 120 -sS "$URL" -o "$DEST" || {
			echo "ERROR: download failed: $URL"
			return 1
		}

		[ -s "$DEST" ] || {
			echo "ERROR: downloaded file is empty: $DEST"
			return 1
		}
	}

	echo "[1/6] Install Linux 6.18 NSS qdisc kernel UAPI patch..."
	fetch "${LEDE_RAW}/target/linux/qualcommax/patches-6.18/0602-1-qca-nss-drv-add-qdisc-support.patch" \
		"${KERNEL_PATCH_DIR}/0602-1-qca-nss-drv-add-qdisc-support.patch" || return 1

	echo "[2/6] Install Linux 6.18 NSS qdisc kernel glue patch..."
	fetch "${LEDE_RAW}/target/linux/qualcommax/patches-6.18/0603-1-qca-nss-clients-add-qdisc-support.patch" \
		"${KERNEL_PATCH_DIR}/0603-1-qca-nss-clients-add-qdisc-support.patch" || return 1

	echo "[3/6] Install iproute2 6.18 NSS qdisc support..."
	fetch "${JULIUS_RAW}/package/network/utils/iproute2/patches/400-add-nss-qdisc.patch" \
		"${IPROUTE_PATCH_DIR}/400-add-nss-qdisc.patch" || return 1

	echo "[4/6] Install iproute2 6.18 NSS mirred support..."
	fetch "${JULIUS_RAW}/package/network/utils/iproute2/patches/500-add-nssmirred.patch" \
		"${IPROUTE_PATCH_DIR}/500-add-nssmirred.patch" || return 1

	echo "[5/6] Install Qosmio NSS SQM scripts..."
	fetch "${QOSMIO_RAW}/sqm-scripts-nss/files/nss-zk.qos" \
		"${SQM_ASSET_DIR}/nss-zk.qos" || return 1
	fetch "${QOSMIO_RAW}/sqm-scripts-nss/files/nss-zk.qos.help" \
		"${SQM_ASSET_DIR}/nss-zk.qos.help" || return 1
	chmod 0644 "${SQM_ASSET_DIR}/nss-zk.qos" "${SQM_ASSET_DIR}/nss-zk.qos.help"

	if ! grep -q 'ZN-M2 NSS SQM 6.18 assets' "${SQM_FEED_MAKEFILE}"; then
		local TMP_SQM_MAKEFILE
		TMP_SQM_MAKEFILE=$(mktemp)

		awk '
			BEGIN { in_install=0; inserted=0 }
			/^define Package\/sqm-scripts\/install$/ {
				print
				in_install=1
				next
			}
			/^endef$/ && in_install {
				print "\t# ZN-M2 NSS SQM 6.18 assets"
				print "\t$(INSTALL_DIR) $(1)/usr/lib/sqm"
				print "\t$(INSTALL_DATA) $(TOPDIR)/package/zn-m2-nss-sqm-assets/nss-zk.qos $(1)/usr/lib/sqm/nss-zk.qos"
				print "\t$(INSTALL_DATA) $(TOPDIR)/package/zn-m2-nss-sqm-assets/nss-zk.qos.help $(1)/usr/lib/sqm/nss-zk.qos.help"
				print "endef"
				in_install=0
				inserted=1
				next
			}
			{ print }
			END {
				if (!inserted) exit 2
			}
		' "${SQM_FEED_MAKEFILE}" > "${TMP_SQM_MAKEFILE}" || {
			rm -f "${TMP_SQM_MAKEFILE}"
			echo "ERROR: could not patch sqm-scripts Makefile."
			return 1
		}

		mv -f "${TMP_SQM_MAKEFILE}" "${SQM_FEED_MAKEFILE}"
	fi

	echo "[6/6] Verify all NSS SQM integration points..."

	grep -q 'TCA_ID_MIRRED_NSS' "${KERNEL_PATCH_DIR}/0602-1-qca-nss-drv-add-qdisc-support.patch" || {
		echo "ERROR: 0602 NSS UAPI patch verification failed."
		return 1
	}

	grep -q 'TCQ_F_NSS' "${KERNEL_PATCH_DIR}/0603-1-qca-nss-clients-add-qdisc-support.patch" || {
		echo "ERROR: 0603 NSS qdisc glue patch verification failed."
		return 1
	}

	grep -q 'q_nss.c' "${IPROUTE_PATCH_DIR}/400-add-nss-qdisc.patch" || {
		echo "ERROR: iproute2 NSS qdisc patch verification failed."
		return 1
	}

	grep -q 'm_nssmirred.c' "${IPROUTE_PATCH_DIR}/500-add-nssmirred.patch" || {
		echo "ERROR: iproute2 nssmirred patch verification failed."
		return 1
	}

	grep -q 'nssfq_codel' "${SQM_ASSET_DIR}/nss-zk.qos" || {
		echo "ERROR: nss-zk.qos verification failed."
		return 1
	}

	grep -q 'action nssmirred' "${SQM_ASSET_DIR}/nss-zk.qos" || {
		echo "ERROR: nss-zk.qos ingress nssmirred path missing."
		return 1
	}

	grep -q 'ZN-M2 NSS SQM 6.18 assets' "${SQM_FEED_MAKEFILE}" || {
		echo "ERROR: sqm-scripts package integration verification failed."
		return 1
	}

	echo "NSS SQM 6.18 integration prepared successfully:"
	echo "  Kernel: 0602 + 0603 (coolsnowwolf/lede, Linux 6.18)"
	echo "  tc:     400 + 500 (JuliusBairaktaris/openwrt-nss-edma, iproute2 6.18)"
	echo "  SQM:    nss-zk.qos (Qosmio)"
	echo "  CONFIG: unchanged"
	echo "=============================================="
}
