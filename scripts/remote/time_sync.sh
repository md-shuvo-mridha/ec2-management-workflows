#!/usr/bin/env bash
set -euo pipefail
source /tmp/ec2mw/lib.sh
need_root

tz="${EC2_TIMEZONE:-}"

log "Time before: $(date -Is)"
if [[ -n "${tz}" ]]; then
  if has_cmd timedatectl; then
    timedatectl set-timezone "${tz}" || true
  elif [[ -e "/usr/share/zoneinfo/${tz}" ]]; then
    ln -sf "/usr/share/zoneinfo/${tz}" /etc/localtime
    echo "${tz}" > /etc/timezone || true
  fi
  log "Timezone set to: ${tz}"
fi

# Prefer chrony if available/installable
if has_cmd systemctl; then
  if systemctl list-unit-files | grep -q '^chronyd\.service'; then
    systemctl enable --now chronyd || true
  elif systemctl list-unit-files | grep -q '^chrony\.service'; then
    systemctl enable --now chrony || true
  elif systemctl list-unit-files | grep -q '^systemd-timesyncd\.service'; then
    systemctl enable --now systemd-timesyncd || true
  fi
fi

if has_cmd timedatectl; then
  timedatectl set-ntp true || true
  timedatectl status || true
fi

log "Time after:  $(date -Is)"
