#!/usr/bin/env bash
set -euo pipefail
source /tmp/ec2mw/lib.sh

# outputs:
#   OS_FAMILY=debian|rhel|amazon
#   PKG_MGR=apt|dnf|yum
#   PRETTY_NAME=...
#   ID=...
#   VERSION_ID=...

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
else
  log "ERROR: /etc/os-release not found"
  exit 1
fi

OS_FAMILY="unknown"
PKG_MGR="unknown"

case "${ID:-}" in
  ubuntu|debian)
    OS_FAMILY="debian"
    PKG_MGR="apt"
    ;;
  amzn)
    OS_FAMILY="amazon"
    if has_cmd dnf; then PKG_MGR="dnf"; else PKG_MGR="yum"; fi
    ;;
  rhel|centos|rocky|almalinux|fedora|ol)
    OS_FAMILY="rhel"
    if has_cmd dnf; then PKG_MGR="dnf"; else PKG_MGR="yum"; fi
    ;;
  *)
    # fallback by available package manager
    if has_cmd apt-get; then OS_FAMILY="debian"; PKG_MGR="apt"; fi
    if has_cmd dnf; then OS_FAMILY="rhel"; PKG_MGR="dnf"; fi
    if has_cmd yum; then OS_FAMILY="rhel"; PKG_MGR="yum"; fi
    ;;
esac

echo "OS_FAMILY=${OS_FAMILY}"
echo "PKG_MGR=${PKG_MGR}"
echo "PRETTY_NAME=${PRETTY_NAME:-unknown}"
echo "ID=${ID:-unknown}"
echo "VERSION_ID=${VERSION_ID:-unknown}"
