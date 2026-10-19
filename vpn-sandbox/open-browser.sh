#!/bin/zsh
# Open a separate browser instance that sends all traffic through the VPN proxy of one sandbox.
# Your normal browser windows do not use the VPN.
# Usage: ./open-browser.sh <sandbox> [browser]
#   browser: chrome, brave, edge, chromium, vivaldi or firefox. The default is the browser column of sandboxes.conf.
set -e
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib.sh"

[[ -n $1 ]] || { usage "$0 <sandbox> [chrome|brave|edge|chromium|vivaldi|firefox]"; exit 1; }
load_sandbox "$1"
browser=${2:-$DEFAULT_BROWSER}
browser=${browser:l}

case $browser in
  chrome)   app="Google Chrome" ;;
  brave)    app="Brave Browser" ;;
  edge)     app="Microsoft Edge" ;;
  chromium) app="Chromium" ;;
  vivaldi)  app="Vivaldi" ;;
  firefox)  app="Firefox" ;;
  *)
    echo "ERROR: Unknown browser: '$browser'. Use chrome, brave, edge, chromium, vivaldi or firefox." >&2
    exit 1 ;;
esac

if [[ ! -d "/Applications/$app.app" && ! -d "$HOME/Applications/$app.app" ]]; then
  echo "ERROR: The application '$app' is not installed." >&2
  exit 1
fi

# Safety check: do not open the browser if the proxy does not work.
require_proxy

profile_dir="$PROFILE_ROOT/$SANDBOX-$browser"
mkdir -p "$profile_dir"
start_page="https://ipinfo.io"

if [[ $browser == firefox ]]; then
  # Firefox has no proxy start option. user.js sets the proxy in the profile at each start.
  cat > "$profile_dir/user.js" <<EOF
// Written by vpn-sandbox/open-browser.sh at each start. Changes here are overwritten.
user_pref("network.proxy.type", 1);
user_pref("network.proxy.http", "127.0.0.1");
user_pref("network.proxy.http_port", $VPN_HTTP_PORT);
user_pref("network.proxy.ssl", "127.0.0.1");
user_pref("network.proxy.ssl_port", $VPN_HTTP_PORT);
user_pref("network.proxy.share_proxy_settings", false);
user_pref("network.proxy.no_proxies_on", "");
// DNS over HTTPS off: the proxy resolves names through the VPN.
user_pref("network.trr.mode", 5);
// WebRTC: use only the proxy, so WebRTC cannot show your real IP address.
user_pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("browser.shell.checkDefaultBrowser", false);
EOF
  open -na "$app" --args -profile "$profile_dir" -no-remote "$start_page"
else
  # Chromium-based browsers.
  # --user-data-dir: a separate profile makes a separate browser instance, so the proxy flag applies.
  # --force-webrtc-ip-handling-policy: stops WebRTC from showing your real IP address.
  open -na "$app" --args \
    --user-data-dir="$profile_dir" \
    --proxy-server="$HTTP_PROXY_URL" \
    --force-webrtc-ip-handling-policy=disable_non_proxied_udp \
    --no-first-run \
    --no-default-browser-check \
    "$start_page"
fi

echo "Opened $app for sandbox '$SANDBOX' (profile: $profile_dir)."
