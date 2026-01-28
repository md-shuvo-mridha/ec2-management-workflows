#!/usr/bin/env bash
set -euo pipefail
source /tmp/ec2mw/lib.sh
need_root

OS_FAMILY="$1"
PKG_MGR="$2"

log "Installing tools for family=${OS_FAMILY}, mgr=${PKG_MGR}"

# Common tools you asked for:
# htop atop iotop nmon sysstat vim nano gcc gcc-c++ make traceroute git curl wget
# net-tools telnet tcpdump wireshark nmap netcat bind-utils mtr iperf3 iproute ethtool
# lsof strace screen tmux rsync tar zip unzip p7zip jq python3 python3-pip

case "${OS_FAMILY}" in
  debian)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    # Debian/Ubuntu package name mapping
    pkgs=(
      htop atop iotop nmon sysstat vim nano
      gcc g++ make
      traceroute git curl wget
      net-tools telnet tcpdump
      wireshark
      nmap netcat-openbsd dnsutils mtr iperf3 iproute2 ethtool
      lsof strace screen tmux rsync
      tar zip unzip p7zip-full
      jq
      python3 python3-pip
    )

    # Wireshark can prompt; keep it noninteractive
    apt-get install -y "${pkgs[@]}"
    ;;
  rhel|amazon)
    # RHEL/Alma/Rocky/CentOS/Amazon mapping
    # Notes:
    # - gcc-c++ exists here
    # - netcat is "nc" sometimes; package "nmap-ncat" is common on RHEL
    # - bind-utils is dig/nslookup
    # - wireshark often "wireshark" or "wireshark-cli" (headless safe)
    if [[ "${PKG_MGR}" == "dnf" ]]; then
      dnf -y makecache
      base_install="dnf -y install"
    else
      yum -y makecache
      base_install="yum -y install"
    fi

    pkgs=(
      htop atop iotop nmon sysstat vim-enhanced nano
      gcc gcc-c++ make
      traceroute git curl wget
      net-tools telnet tcpdump
      wireshark-cli
      nmap nmap-ncat bind-utils mtr iperf3 iproute ethtool
      lsof strace screen tmux rsync
      tar zip unzip p7zip
      jq
      python3 python3-pip
    )

    # Some distros may not have certain pkgs by default; install what exists
    missing=()
    for p in "${pkgs[@]}"; do
      if ! ${base_install} "${p}" >/dev/null 2>&1; then
        missing+=("${p}")
      fi
    done

    if [[ "${#missing[@]}" -gt 0 ]]; then
      log "Some packages failed (repo may lack them). Missing/failed:"
      printf '%s\n' "${missing[@]}"
      log "Tip: enable EPEL on RHEL-like distros if needed."
    fi
    ;;
  *)
    log "ERROR: unsupported OS family: ${OS_FAMILY}"
    exit 1
    ;;
esac

log "Tools install done."
