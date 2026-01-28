#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date -Is)] $*"; }

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "ERROR: must run as root"
    exit 1
  fi
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }
