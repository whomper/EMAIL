#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 AERA | Erez Yaary
# Set up a Raspberry Pi (or any Debian/Ubuntu/Raspberry Pi OS computer)
# as EMail's secure-mail gateway: the Atari talks plain IMAP, POP3 and
# SMTP to the Pi on your home network, and emailgate.py on the Pi talks
# TLS to your mail provider.
#
#   sudo ./install.sh imap.gmail.com smtp.gmail.com [pop.gmail.com]
#   sudo ./install.sh --allow 192.168.1.50 imap.gmail.com smtp.gmail.com
#   sudo ./install.sh imap.mail.me.com smtp.mail.me.com:587     (iCloud)
#
# Anyone on your home network may use it (private addresses only), or
# with --allow ATARI_IP only the Atari.
# --ports I,S,P     the ports on the Pi for IMAP, SMTP and POP3, when the
#                   usual ones are taken (e.g. by another bridge):
#   sudo ./install.sh --ports 1143,1025,1110 imap.gmail.com smtp.gmail.com
#
# Ports on the Pi, to type into EMail's account dialog (unless --ports):
#   IMAP 143   POP3 110   SMTP 587   (the standard ones)
#
# Run it again to change the settings; `sudo ./install.sh --remove` takes it
# away. It replaces the stunnel set-up earlier versions made.
set -euo pipefail

USAGE="usage: install.sh [--allow ATARI_IP] [--ports IMAP,SMTP,POP3] IMAP_SERVER SMTP_SERVER[:587] [POP3_SERVER]
       install.sh --remove"
ALLOW=""
ARGS=()
P_IMAP=143 P_SMTP=587 P_POP3=110
OLD=/etc/stunnel/atari-mail.conf

stop_stunnel() {
  # the stunnel set-up of EMail 1.x: gone, and stunnel too unless it has
  # other work
  [ -f "$OLD" ] || return 0
  rm -f "$OLD"
  if ls /etc/stunnel/*.conf >/dev/null 2>&1; then
    systemctl restart stunnel4 2>/dev/null || true
    echo "Removed EMail's old stunnel set-up ($OLD); stunnel keeps running for the others."
  else
    systemctl disable --now stunnel4 >/dev/null 2>&1 || true
    echo "Removed EMail's old stunnel set-up ($OLD) and stopped stunnel."
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --allow) ALLOW=${2:?$USAGE}; ARGS+=(--allow "$ALLOW"); shift 2 ;;
    --ports)
      IFS=, read -r P_IMAP P_SMTP P_POP3 <<<"${2:?$USAGE}"
      P_POP3=${P_POP3:-110}
      shift 2 ;;
    --remove)
      [ "$(id -u)" = 0 ] || { echo "Please run with sudo." >&2; exit 1; }
      systemctl disable --now emailgate.service 2>/dev/null || true
      rm -f /etc/systemd/system/emailgate.service /usr/local/bin/emailgate.py
      systemctl daemon-reload
      stop_stunnel
      echo "emailgate removed."
      exit 0 ;;
    -*) echo "$USAGE" >&2; exit 2 ;;
    *) break ;;
  esac
done
IMAP=${1:?$USAGE}
SMTP=${2:?$USAGE}
POP3=${3:-}

if [ "$(id -u)" != 0 ]; then
  echo "Please run with sudo." >&2
  exit 1
fi
for p in "$P_IMAP" "$P_SMTP" "$P_POP3"; do
  [[ "$p" =~ ^[0-9]+$ ]] || { echo "--ports: $p isn't a port number" >&2; exit 2; }
done
if ! command -v python3 >/dev/null; then
  apt-get update -qq
  apt-get install -y -qq python3
fi
# the system's root certificates, for checking the providers
[ -f /etc/ssl/certs/ca-certificates.crt ] || apt-get install -y -qq ca-certificates

stop_stunnel

HERE=$(cd "$(dirname "$0")" && pwd)
install -m 755 "$HERE/emailgate.py" /usr/local/bin/emailgate.py
id emailgate >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin emailgate

cat > /etc/systemd/system/emailgate.service <<UNIT
[Unit]
Description=EMail gateway for the Atari (TLS to the mail provider)
After=network-online.target
Wants=network-online.target

[Service]
User=emailgate
ExecStart=/usr/bin/python3 /usr/local/bin/emailgate.py -v --ports $P_IMAP,$P_SMTP,$P_POP3 ${ARGS[*]:-} $IMAP $SMTP $POP3
Restart=always
RestartSec=5
# the mail ports are below 1024: that one privilege, and no other
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable emailgate.service >/dev/null
systemctl restart emailgate.service

# a firewall that is on must let the Atari in, or it can't connect; if a
# rule can't be added, say so and stop
PORTS="$P_IMAP $P_SMTP"
[ -n "$POP3" ] && PORTS="$PORTS $P_POP3"
if command -v ufw >/dev/null && ufw status | grep -q "^Status: active"; then
  for p in $PORTS; do
    if [ -n "$ALLOW" ]; then FROM="$ALLOW"; else FROM="192.168.0.0/16 10.0.0.0/8 172.16.0.0/12"; fi
    for f in $FROM; do
      if ! ufw allow from "$f" to any port "$p" proto tcp >/dev/null; then
        echo "Couldn't let $f in on port $p with ufw: stopping. The gateway runs, but the" >&2
        echo "firewall may keep the Atari out; add the rule by hand:" >&2
        echo "   sudo ufw allow from $f to any port $p proto tcp" >&2
        exit 1
      fi
    done
  done
fi

sleep 2
if ! systemctl is-active --quiet emailgate.service; then
  echo "emailgate didn't start; see: sudo journalctl -u emailgate -n 30" >&2
  exit 1
fi
for p in $PORTS; do
  if ! ss -ltn "( sport = :$p )" | grep -q LISTEN; then
    echo "Nothing listens on port $p (another program may have it); see: sudo journalctl -u emailgate -n 30" >&2
    exit 1
  fi
done

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
IP=${IP:-PI_IP}
cat <<MSG

The gateway is running$( [ -n "$ALLOW" ] && echo " for $ALLOW only"). In EMail's account dialog (Options > Accounts):

  Incoming:  IMAP   Server: $IP   Port: $P_IMAP
$( [ -n "$POP3" ] && echo "  (or POP3        Server: $IP   Port: $P_POP3)" )
  Outgoing (SMTP)   Server: $IP   Port: $P_SMTP

with your usual mail user name and password (for Gmail: an app password).
MSG
