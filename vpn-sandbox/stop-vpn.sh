#!/bin/zsh
# Stop the VPN container of one sandbox, or of all sandboxes.
# Applications that use a stopped sandbox then cannot connect.
# Usage: ./stop-vpn.sh <sandbox>|all
set -e
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib.sh"

[[ -n $1 ]] || { usage "$0 <sandbox>|all"; exit 1; }

for name in $(expand_sandboxes "$1"); do
  load_sandbox "$name"
  if [[ -z $(sandbox_status "$SANDBOX") ]]; then
    echo "$SANDBOX is not running."
  else
    echo "Stopping $SANDBOX..."
  fi
  # Also run "down" for a stopped sandbox, to remove a stopped container and its network.
  sandbox_compose down
done
