#!/usr/bin/env bash
set -euo pipefail
source /tmp/ec2mw/lib.sh
need_root

new_hostname="${NEW_HOSTNAME:-}"
hosts_entries="${HOSTS_ENTRIES:-}"
dns_names="${DNS_NAMES:-}"
tcp_targets="${TCP_TARGETS:-}"
dry_run="${DRY_RUN:-false}"

MANAGED_BEGIN="# BEGIN EC2MW MANAGED HOSTS"
MANAGED_END="# END EC2MW MANAGED HOSTS"

is_valid_hostname() {
  local h="$1"
  [[ "${#h}" -le 253 ]] || return 1
  [[ "$h" =~ ^[a-z0-9]([a-z0-9\-\.]*[a-z0-9])?$ ]] || return 1
  IFS='.' read -r -a labels <<< "$h"
  for lab in "${labels[@]}"; do
    [[ -n "$lab" ]] || return 1
    [[ "${#lab}" -le 63 ]] || return 1
    [[ "$lab" =~ ^[a-z0-9]([a-z0-9\-]*[a-z0-9])?$ ]] || return 1
  done
  return 0
}

apply_or_echo() {
  if [[ "${dry_run}" == "true" ]]; then
    log "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

ensure_managed_block() {
  if ! grep -qF "${MANAGED_BEGIN}" /etc/hosts; then
    apply_or_echo "cat >> /etc/hosts <<'BLK'

${MANAGED_BEGIN}
${MANAGED_END}
BLK"
  fi
}

update_managed_hosts() {
  local entries="$1"
  [[ -z "$entries" ]] && return 0

  ensure_managed_block

  # wipe content inside block (keep markers)
  apply_or_echo "sed -i '/${MANAGED_BEGIN}/,/${MANAGED_END}/{//!d}' /etc/hosts"

  IFS=',' read -r -a arr <<< "$entries"
  for e in "${arr[@]}"; do
    e="$(echo "${e}" | xargs)" || true
    [[ -z "${e}" ]] && continue
    ip="${e%%:*}"
    hn="${e#*:}"

    hn="$(echo "${hn}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9\.\-]/-/g' | sed 's/--\+/-/g' | sed 's/^\-//; s/\-$//')"
    [[ -z "${ip}" || -z "${hn}" || "${ip}" == "${hn}" ]] && continue

    apply_or_echo "sed -i \"/${MANAGED_END}/i ${ip} ${hn}\" /etc/hosts"
  done
}

check_resolve() {
  local name="$1"
  local out=""
  if has_cmd getent; then
    out="$(getent hosts "${name}" 2>/dev/null || true)"
  fi
  if [[ -z "${out}" ]] && has_cmd dig; then
    out="$(dig +short "${name}" A 2>/dev/null || true)"
  fi
  echo "${out}"
}

check_ping() {
  local name="$1"
  if has_cmd ping; then
    ping -c 2 -W 2 "${name}" >/dev/null 2>&1 && echo "ok" || echo "fail"
  else
    echo "no-ping"
  fi
}

check_tcp() {
  local hp="$1"
  local host="${hp%:*}"
  local port="${hp#*:}"
  if has_cmd nc; then
    nc -z -w 2 "${host}" "${port}" >/dev/null 2>&1 && echo "ok" || echo "fail"
  else
    timeout 2 bash -lc "cat < /dev/null > /dev/tcp/${host}/${port}" >/dev/null 2>&1 && echo "ok" || echo "fail"
  fi
}

log "Start hostname/hosts/dns check"
log "Dry-run: ${dry_run}"

if [[ -z "${new_hostname}" ]]; then
  log "ERROR: NEW_HOSTNAME is empty"
  exit 1
fi

# --- ENTERPRISE SANITIZE (this is the one you referenced) ---
new_hostname="$(echo "${new_hostname}" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9\.\-]/-/g' \
  | sed 's/\.\././g' \
  | sed 's/--\+/-/g' \
  | sed 's/^\-//; s/\-$//')"
# -----------------------------------------------------------

if ! is_valid_hostname "${new_hostname}"; then
  log "ERROR: invalid hostname after sanitize: ${new_hostname}"
  exit 1
fi

if ! sudo -n true >/dev/null 2>&1; then
  log "ERROR: sudo requires password (NOPASSWD not set)"
  exit 1
fi

current_hostname="$(hostname)"
os_pretty="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
now="$(date -Is)"

changed_hostname="no"
changed_hosts="no"

log "Current hostname: ${current_hostname}"
log "Target hostname:  ${new_hostname}"

# Apply hostname (idempotent)
if [[ "${current_hostname}" != "${new_hostname}" ]]; then
  apply_or_echo "hostnamectl set-hostname ${new_hostname} || (echo ${new_hostname} > /etc/hostname; hostname ${new_hostname} || true)"
  changed_hostname="yes"
fi

# Ensure Ubuntu style 127.0.1.1 hostname line
if grep -qE '^127\.0\.1\.1[[:space:]]+' /etc/hosts; then
  if ! grep -qE "^127\.0\.1\.1[[:space:]]+${new_hostname}(\$|[[:space:]])" /etc/hosts; then
    apply_or_echo "sed -i \"s/^127\\.0\\.1\\.1[[:space:]].*/127.0.1.1 ${new_hostname}/\" /etc/hosts"
    changed_hosts="yes"
  fi
else
  apply_or_echo "printf '\n127.0.1.1 %s\n' '${new_hostname}' >> /etc/hosts"
  changed_hosts="yes"
fi

# Managed hosts block update (safe)
if [[ -n "${hosts_entries}" ]]; then
  update_managed_hosts "${hosts_entries}"
  changed_hosts="yes"
fi

final_hostname="$(hostname)"
log "Final hostname: ${final_hostname}"

resolve_results=()
ping_results=()
tcp_results=()

# DNS resolve + ping
if [[ -n "${dns_names}" ]]; then
  IFS=',' read -r -a names <<< "${dns_names}"
  for name in "${names[@]}"; do
    name="$(echo "${name}" | xargs)" || true
    [[ -z "${name}" ]] && continue

    r="$(check_resolve "${name}")"
    p="$(check_ping "${name}")"

    resolve_results+=("${name}=$(echo "${r}" | tr '\n' ' ' | xargs)")
    ping_results+=("${name}=${p}")

    log "DNS: ${name} -> ${r:-<no result>}"
    log "PING: ${name} -> ${p}"
  done
fi

# Optional TCP checks (useful when ping blocked)
if [[ -n "${tcp_targets}" ]]; then
  IFS=',' read -r -a tgs <<< "${tcp_targets}"
  for t in "${tgs[@]}"; do
    t="$(echo "${t}" | xargs)" || true
    [[ -z "${t}" ]] && continue
    s="$(check_tcp "${t}")"
    tcp_results+=("${t}=${s}")
    log "TCP: ${t} -> ${s}"
  done
fi

echo "JSON_BEGIN"
python3 - <<PY
import json
data = {
  "time": "${now}",
  "os": "${os_pretty}",
  "current_hostname": "${current_hostname}",
  "final_hostname": "${final_hostname}",
  "changed_hostname": "${changed_hostname}",
  "changed_hosts": "${changed_hosts}",
  "dry_run": "${dry_run}",
  "resolve_results": ${json.dumps(resolve_results)},
  "ping_results": ${json.dumps(ping_results)},
  "tcp_results": ${json.dumps(tcp_results)},
}
print(json.dumps(data, indent=2))
PY
echo "JSON_END"

log "Done."
