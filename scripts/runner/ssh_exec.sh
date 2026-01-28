#!/usr/bin/env bash
set -euo pipefail

host="$1"; shift
remote_cmd="$*"

port="${EC2_PORT:-22}"
user="${EC2_USER:?EC2_USER secret missing}"

# Create temp key
key_file="$(mktemp)"
chmod 600 "${key_file}"
printf '%s\n' "${EC2_SSH_KEY:?EC2_SSH_KEY secret missing}" > "${key_file}"

# SSH hardening defaults (can override via EC2_SSH_OPTS)
ssh_opts=(
  -i "${key_file}"
  -p "${port}"
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="${GITHUB_WORKSPACE:-/tmp}/.known_hosts"
  -o ConnectTimeout=10
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
)
if [[ -n "${EC2_SSH_OPTS:-}" ]]; then
  # shellcheck disable=SC2206
  ssh_opts+=(${EC2_SSH_OPTS})
fi

set +e
ssh "${ssh_opts[@]}" "${user}@${host}" "bash -lc $(printf '%q' "${remote_cmd}")"
rc=$?
set -e

rm -f "${key_file}"
exit $rc
