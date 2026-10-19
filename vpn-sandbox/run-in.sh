#!/bin/zsh
# Run a command with the proxy environment variables of one sandbox.
# Usage: ./run-in.sh <sandbox> <command> [arguments...]
# Examples:
#   ./run-in.sh germany curl https://ipinfo.io
#   ./run-in.sh germany zsh        (a shell where tools that read the variables use the VPN)
#
# CAUTION: Only tools that read HTTP_PROXY, HTTPS_PROXY or ALL_PROXY use the VPN.
# A tool that ignores these variables connects directly, without the VPN, and does not show an error.
set -e
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib.sh"

if [[ -z $1 || -z $2 ]]; then
  usage "$0 <sandbox> <command> [arguments...]"
  exit 1
fi
load_sandbox "$1"
shift

require_proxy

# Both spellings: some tools read only the uppercase names, and other tools read only the lowercase names.
export HTTP_PROXY=$HTTP_PROXY_URL  http_proxy=$HTTP_PROXY_URL
export HTTPS_PROXY=$HTTP_PROXY_URL https_proxy=$HTTP_PROXY_URL
export ALL_PROXY=$SOCKS_PROXY_URL  all_proxy=$SOCKS_PROXY_URL
export NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1
export VPN_SANDBOX=$SANDBOX

exec "$@"
