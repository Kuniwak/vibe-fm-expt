#!/bin/sh
# Usage: apply.sh allowlist|open   (allowed domains are read from stdin-free env ALLOW_DOMAINS)
set -eu
mode="${1:-allowlist}"
log() { echo "$@"; }

if [ "$mode" = open ]; then
  log "mode: open (no egress filtering)"
  log "READY"
  exec sleep infinity
fi

[ "$mode" = allowlist ] || { echo "unknown mode: $mode" >&2; exit 2; }

ipset create allowed hash:net family inet
nameservers=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf)
log "mode: allowlist"
log "nameservers: $(echo $nameservers)"
for d in $ALLOW_DOMAINS; do
  ips=$(dig +short +time=3 +tries=2 A "$d" | grep -E '^[0-9.]+$' || true)
  [ -n "$ips" ] || { echo "failed to resolve $d" >&2; exit 1; }
  for ip in $ips; do ipset -exist add allowed "$ip"; done
  log "allow $d -> $(echo $ips)"
done

iptables -F; iptables -X
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
for ns in $nameservers; do
  iptables -A OUTPUT -p udp -d "$ns" --dport 53 -j ACCEPT
  iptables -A OUTPUT -p tcp -d "$ns" --dport 53 -j ACCEPT
done
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
if ip6tables -L >/dev/null 2>&1; then
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A INPUT -i lo -j ACCEPT
  ip6tables -P INPUT DROP; ip6tables -P FORWARD DROP; ip6tables -P OUTPUT DROP
fi
log "--- iptables-save"
iptables-save
log "--- ipset"
ipset list allowed
log "READY"
exec sleep infinity
