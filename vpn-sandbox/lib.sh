# Shared functions for the vpn-sandbox scripts. Source this file after SCRIPT_DIR is set.

CONF="$SCRIPT_DIR/sandboxes.conf"
PROFILE_ROOT="$HOME/.vpn-sandbox/profiles"

# Print the sandbox lines of sandboxes.conf, one line per sandbox, with tab-separated, trimmed fields.
sandbox_lines() {
  awk -F'|' '!/^[[:space:]]*(#|$)/ {
    for (i = 1; i <= NF; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i)
    OFS = "\t"; $1 = $1; print
  }' "$CONF"
}

sandbox_names() {
  sandbox_lines | cut -f1
}

# Print a usage line and the list of sandboxes. Arguments: the usage text.
usage() {
  echo "Usage: $*" >&2
  echo "Sandboxes: $(sandbox_names | tr '\n' ' ')" >&2
}

# Load the settings of one sandbox into variables. Return 1 if the name is unknown.
load_sandbox() {
  local name=${1:l} line
  line=$(sandbox_lines | awk -F'\t' -v n="$name" '$1 == n')
  if [[ -z $line ]]; then
    echo "ERROR: Unknown sandbox: '$1'" >&2
    echo "Sandboxes: $(sandbox_names | tr '\n' ' ')" >&2
    return 1
  fi
  IFS=$'\t' read -r SANDBOX VPN_PROVIDER VPN_COUNTRY VPN_HTTP_PORT VPN_SOCKS_PORT VPN_TZ DEFAULT_BROWSER <<< "$line"
  COMPOSE_PROJECT="vpn-sandbox-$SANDBOX"
  VPN_CONTAINER="vpn-sandbox-$SANDBOX"
  ENV_FILE="$SCRIPT_DIR/.env.$VPN_PROVIDER"
  HTTP_PROXY_URL="http://127.0.0.1:$VPN_HTTP_PORT"
  SOCKS_PROXY_URL="socks5h://127.0.0.1:$VPN_SOCKS_PORT"
  export VPN_PROVIDER VPN_COUNTRY VPN_HTTP_PORT VPN_SOCKS_PORT VPN_TZ VPN_CONTAINER
}

# Print the names of the sandboxes in the argument: a sandbox name, or "all".
expand_sandboxes() {
  if [[ $1 == all ]]; then
    sandbox_names
  else
    print -r -- "$1"
  fi
}

# Print the Docker status of the container of a sandbox name, for example "Up 9 minutes (healthy)".
# Print nothing if the container does not run.
sandbox_status() {
  docker ps --filter "name=^/vpn-sandbox-$1\$" --format '{{.Status}}' 2>/dev/null
}

# Run docker compose for the loaded sandbox.
sandbox_compose() {
  docker compose -p "$COMPOSE_PROJECT" -f "$SCRIPT_DIR/docker-compose.yml" "$@"
}

# Print "ip, city, country" through a proxy, or directly when no proxy is given.
# ipinfo.io refuses some shared VPN addresses (HTTP 429). Then use the Cloudflare trace page (no city).
public_ip() {
  local args=(-sf --max-time 10) out
  [[ -n $1 ]] && args+=(--proxy "$1")
  if out=$(curl "${args[@]}" https://ipinfo.io/json); then
    print -r -- "$out" | grep -E '"(ip|city|country)"' | tr -d ' \n'
  elif out=$(curl "${args[@]}" https://www.cloudflare.com/cdn-cgi/trace); then
    print -r -- "$out" | grep -E '^(ip|loc)=' | tr '\n' ' '
  fi
}

# Return 0 if the proxy (HTTP or SOCKS5 URL) forwards traffic to the internet.
proxy_works() {
  curl -sf -o /dev/null --max-time 5 --proxy "$1" https://www.cloudflare.com/cdn-cgi/trace
}

# Stop with an error if the HTTP proxy of the loaded sandbox does not work.
require_proxy() {
  if ! proxy_works "$HTTP_PROXY_URL"; then
    echo "ERROR: The VPN proxy of '$SANDBOX' does not work. Run ./start-vpn.sh $SANDBOX first." >&2
    exit 1
  fi
}
