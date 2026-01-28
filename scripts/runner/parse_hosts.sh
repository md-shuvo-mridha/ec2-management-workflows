#!/usr/bin/env bash
set -euo pipefail

# input: env EC2_HOSTS="a,b c"
# output: newline-separated hosts
hosts_raw="${1:-${EC2_HOSTS:-}}"

if [[ -z "${hosts_raw}" ]]; then
  echo "ERROR: EC2_HOSTS is empty" >&2
  exit 1
fi

echo "${hosts_raw}" \
  | tr ',;' '  ' \
  | tr -s ' ' '\n' \
  | sed '/^$/d'
