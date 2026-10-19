#!/bin/zsh
# Start the VPN container of one sandbox, or of all sandboxes, and wait until the VPN connection is ready.
# Usage: ./start-vpn.sh <sandbox>|all    (sandboxes are in sandboxes.conf)
set -e
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib.sh"

[[ -n $1 ]] || { usage "$0 <sandbox>|all"; exit 1; }

start_one() {
  load_sandbox "$1" || return 1

  local env_name=${ENV_FILE:t}
  if [[ ! -f $ENV_FILE ]]; then
    echo "ERROR: The credentials file $env_name does not exist." >&2
    if [[ -f $ENV_FILE.example ]]; then
      echo "Copy $env_name.example to $env_name and put your $VPN_PROVIDER credentials in $env_name." >&2
    else
      echo "Make $env_name with the Gluetun settings of $VPN_PROVIDER (see README)." >&2
    fi
    return 1
  fi

  if grep -q "REPLACE_WITH" "$ENV_FILE"; then
    echo "ERROR: Put your $VPN_PROVIDER credentials in $env_name first." >&2
    return 1
  fi

  local sandbox_state=$(sandbox_status "$SANDBOX")
  if [[ -n $sandbox_state ]]; then
    echo "$SANDBOX is already running: $sandbox_state. Checking the connection..."
  fi

  sandbox_compose up -d || return 1

  [[ -z $sandbox_state ]] && echo "Waiting for the VPN connection ($SANDBOX, HTTP port $VPN_HTTP_PORT, SOCKS5 port $VPN_SOCKS_PORT)..."
  for i in {1..60}; do
    if proxy_works "$HTTP_PROXY_URL"; then
      echo "VPN is ready. $SANDBOX: $(public_ip "$HTTP_PROXY_URL")"
      return 0
    fi
    sleep 2
  done

  echo "ERROR: The VPN did not become ready. Read the log with: docker logs $VPN_CONTAINER" >&2
  return 1
}

failed=0
requested=($(expand_sandboxes "$1"))
for name in $requested; do
  start_one "$name" || failed=1
done

# Tell which other sandboxes also run, so that the output of check-ip.sh is not a surprise.
others=()
for name in $(sandbox_names); do
  (( ${requested[(Ie)$name]} )) && continue
  state=$(sandbox_status "$name")
  [[ -n $state ]] && others+=("$name: $state")
done
if (( ${#others} )); then
  echo
  echo "Other sandboxes that also run:"
  printf "  %s\n" "${others[@]}"
  echo "To stop one, run: ./vpn-sandbox/stop-vpn.sh <sandbox>"
fi

exit $failed
