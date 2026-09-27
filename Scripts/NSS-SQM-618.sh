#!/bin/bash

# ZN-M2 / IPQ6018 / Linux 6.18 NSS SQM integration.
#
# IMPORTANT:
#   VIKINGYFY/immortalwrt already carries the Linux 6.18 NSS qdisc patches
#   (0602/0603) and iproute2 NSS patches (400/500) in the upstream tree.
#   Do NOT overwrite those upstream patches here.
#
# NSS package feed:
#   qosmio/nss-packages @ NSS-12.5-K6.x
#   Provides qca-nss-drv / qca-nss-drv-qdisc / qca-nss-drv-igs / nss-firmware.
#
# Only the NSS-specific SQM script asset is injected here:
#   qosmio/sqm-scripts-nss @ 4b4ed8639229be5e70cf94b73cdf7dbc09e66d5d
#
# Do not change .config here. Package selections stay in the build Settings.sh.

apply_nss_sqm_618() {
	local WRT_ROOT="${GITHUB_WORKSPACE}/wrt"
	local KERNEL_PATCH_DIR="${WRT_ROOT}/target/linux/qualcommax/patches-6.18"
	local IPROUTE_PATCH_DIR="${WRT_ROOT}/package/network/utils/iproute2/patches"
	local SQM_FEED_MAKEFILE="${WRT_ROOT}/feeds/packages/net/sqm-scripts/Makefile"
	local SQM_ASSET_DIR="${WRT_ROOT}/package/zn-m2-nss-sqm-assets"

	local QOSMIO_REF="4b4ed8639229be5e70cf94b73cdf7dbc09e66d5d"
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
		echo "ERROR: iproute2 6.18.0 was not found; refusing NSS SQM integration."
		return 1
	fi

	if [ ! -f "${SQM_FEED_MAKEFILE}" ]; then
		echo "ERROR: sqm-scripts feed Makefile not found: ${SQM_FEED_MAKEFILE}"
		return 1
	fi

	# VIKINGYFY already ships the kernel/tc NSS qdisc patches.
	# Verify them in place, but never replace them with a third-party copy.
	echo "[1/4] Verify VIKINGYFY upstream NSS kernel/tc patches..."

	grep -q 'TCA_ID_MIRRED_NSS' "${KERNEL_PATCH_DIR}/0602-1-qca-nss-drv-add-qdisc-support.patch" || {
		echo "ERROR: upstream 0602 NSS qdisc patch missing or incomplete."
		return 1
	}

	grep -q 'TCQ_F_NSS' "${KERNEL_PATCH_DIR}/0603-1-qca-nss-clients-add-qdisc-support.patch" || {
		echo "ERROR: upstream 0603 NSS qdisc patch missing or incomplete."
		return 1
	}

	# The current VIKINGYFY 0603 includes the split RX/TX stats locking fix.
	grep -q 'u64_stats_update_begin(&txp->tx_stats.sync)' 		"${KERNEL_PATCH_DIR}/0603-1-qca-nss-clients-add-qdisc-support.patch" || {
		echo "ERROR: upstream 0603 patch is not the current VIKINGYFY variant."
		return 1
	}

	grep -q 'q_nss.c' "${IPROUTE_PATCH_DIR}/400-add-nss-qdisc.patch" || {
		echo "ERROR: upstream iproute2 400 NSS qdisc patch missing or incomplete."
		return 1
	}

	grep -q 'm_nssmirred.c' "${IPROUTE_PATCH_DIR}/500-add-nssmirred.patch" || {
		echo "ERROR: upstream iproute2 500 NSS mirred patch missing or incomplete."
		return 1
	}

	# Kernel patches provide the NSS qdisc ABI/hooks; the actual modules and firmware come from the NSS feed.
	local NSS_FEED_DIR="${WRT_ROOT}/feeds/nss_packages"
	if [ ! -f "${NSS_FEED_DIR}/qca-nss-drv/Makefile" ] || [ ! -f "${NSS_FEED_DIR}/qca-nss-clients/Makefile" ]; then
		echo "ERROR: Qosmio NSS-12.5-K6.x package feed is missing."
		return 1
	fi
	grep -q 'define KernelPackage/qca-nss-drv-qdisc' "${NSS_FEED_DIR}/qca-nss-clients/Makefile" || {
		echo "ERROR: qca-nss-drv-qdisc package is missing from NSS feed."
		return 1
	}
	# Qosmio uses the generic TARGET_qualcommax dependency for the base NSS driver/qdisc.
	# IPQ6018 is selected by CONFIG_TARGET_SUBTARGET=ipq60xx in the driver and by
	# the ipq60xx subtarget list used by NSS clients.
	grep -Eq 'CONFIG_TARGET_SUBTARGET.*"ipq60xx"|else ifeq \\([\\$][\\(]CONFIG_TARGET_SUBTARGET[\\)], "ipq60xx"\\)' "${NSS_FEED_DIR}/qca-nss-drv/Makefile" || {
		echo "ERROR: NSS driver feed has no IPQ60xx subtarget handling."
		return 1
	}
	grep -Eq 'findstring \\$\\(subtarget\\).*"ipq60xx"' "${NSS_FEED_DIR}/qca-nss-clients/Makefile" || {
		echo "ERROR: NSS clients feed has no IPQ60xx subtarget handling."
		return 1
	}

	mkdir -p "${SQM_ASSET_DIR}"

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

	echo "[2/4] Install Qosmio NSS SQM script asset..."
	fetch "${QOSMIO_RAW}/sqm-scripts-nss/files/nss-zk.qos" 		"${SQM_ASSET_DIR}/nss-zk.qos" || return 1
	fetch "${QOSMIO_RAW}/sqm-scripts-nss/files/nss-zk.qos.help" 		"${SQM_ASSET_DIR}/nss-zk.qos.help" || return 1
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
				print "\t\$(INSTALL_DIR) \$(1)/usr/lib/sqm"
				print "\t\$(INSTALL_DATA) \$(TOPDIR)/package/zn-m2-nss-sqm-assets/nss-zk.qos \$(1)/usr/lib/sqm/nss-zk.qos"
				print "\t\$(INSTALL_DATA) \$(TOPDIR)/package/zn-m2-nss-sqm-assets/nss-zk.qos.help \$(1)/usr/lib/sqm/nss-zk.qos.help"
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

	echo "[3/4] Verify final NSS SQM integration..."

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
	echo "  Kernel: VIKINGYFY upstream 0602 + 0603 (verified, not overwritten)"
	echo "  tc:     VIKINGYFY upstream 400 + 500 (verified, not overwritten)"
	echo "  NSS:    qosmio/nss-packages NSS-12.5-K6.x (qca-nss-drv + qdisc + IGS + firmware)"
	echo "  SQM:    nss-zk.qos (Qosmio)"
	echo "  CONFIG: unchanged"
	echo "=============================================="
}
