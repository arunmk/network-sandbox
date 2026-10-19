#!/bin/zsh
# Show the public IP address without the VPN and through the proxies of each sandbox.
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib.sh"

direct=$(public_ip)
printf "%-14s %-12s %-6s %s\n" "SANDBOX" "PORTS" "SOCKS5" "PUBLIC IP (through the HTTP proxy)"
printf "%-14s %-12s %-6s %s\n" "direct" "-" "-" "${direct:-not available}"

for name in $(sandbox_names); do
  load_sandbox "$name"
  vpn=$(public_ip "$HTTP_PROXY_URL")
  if proxy_works "$SOCKS_PROXY_URL"; then socks=ok; else socks=failed; fi
  [[ -z $vpn ]] && socks=-
  printf "%-14s %-12s %-6s %s\n" "$SANDBOX" "$VPN_HTTP_PORT/$VPN_SOCKS_PORT" "$socks" "${vpn:-not running - run ./start-vpn.sh $SANDBOX}"
done
