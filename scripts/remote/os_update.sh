#!/usr/bin/env bash
set -euo pipefail
source /tmp/ec2mw/lib.sh
need_root

OS_FAMILY="$1"
PKG_MGR="$2"

log "Refreshing repos + updating OS: family=${OS_FAMILY}, mgr=${PKG_MGR}"

case "${PKG_MGR}" in
  apt)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get -y upgrade
    apt-get -y autoremove
    ;;
  dnf)
    dnf -y makecache
    dnf -y upgrade
    ;;
  yum)
    yum -y makecache
    yum -y update
    ;;
  *)
    log "ERROR: unknown package manager: ${PKG_MGR}"
    exit 1
    ;;
esac

# Reboot hint (best-effort)
reboot_needed="no"
if [[ "${PKG_MGR}" == "apt" ]] && [[ -f /var/run/reboot-required ]]; then
  reboot_needed="yes"
fi
if has_cmd needs-restarting; then
  if needs-restarting -r >/dev/null 2>&1; then reboot_needed="yes"; fi
fi

log "Reboot required: ${reboot_needed}"
echo "REBOOT_REQUIRED=${reboot_needed}"
