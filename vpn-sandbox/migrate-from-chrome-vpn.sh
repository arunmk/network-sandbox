#!/bin/zsh
# One-time migration from the old chrome-vpn setup to vpn-sandbox.
#   1. Removes the old containers: chrome-vpn-gluetun, chrome-vpn-germany, chrome-vpn-netherlands.
#   2. Moves the old Chrome profiles to ~/.vpn-sandbox/profiles/<sandbox>-chrome (bookmarks and logins stay).
#   3. Starts all sandboxes with the new names and the new SOCKS5 ports.
# CAUTION: Close all old VPN Chrome windows before you run this script.
# You can run the script again. It skips the steps that are already done.
set -e
SCRIPT_DIR="${0:A:h}"

if pgrep -f -- "--user-data-dir=$HOME/.chrome-vpn" >/dev/null; then
  echo "ERROR: An old VPN Chrome instance is still open. Close all VPN Chrome windows (Cmd + Q) and run this script again." >&2
  exit 1
fi

echo "Removing the old containers and networks..."
for c in chrome-vpn-gluetun chrome-vpn-germany chrome-vpn-netherlands; do
  docker rm -f "$c" >/dev/null 2>&1 && echo "  removed container $c" || true
done
for n in chrome-vpn_default chrome-vpn-germany_default chrome-vpn-netherlands_default; do
  docker network rm "$n" >/dev/null 2>&1 && echo "  removed network $n" || true
done

echo "Moving the old Chrome profiles..."
mkdir -p "$HOME/.vpn-sandbox/profiles"
typeset -A moves=(
  "$HOME/.chrome-vpn-profile"     "$HOME/.vpn-sandbox/profiles/poland-chrome"
  "$HOME/.chrome-vpn-germany"     "$HOME/.vpn-sandbox/profiles/germany-chrome"
  "$HOME/.chrome-vpn-netherlands" "$HOME/.vpn-sandbox/profiles/netherlands-chrome"
)
for src dst in "${(@kv)moves}"; do
  if [[ -d $src && ! -e $dst ]]; then
    mv "$src" "$dst"
    echo "  moved ${src/#$HOME/~} -> ${dst/#$HOME/~}"
  elif [[ -d $src && -e $dst ]]; then
    echo "  WARNING: both ${src/#$HOME/~} and ${dst/#$HOME/~} exist. Nothing moved. Check them manually." >&2
  fi
done

echo "Starting all sandboxes..."
"$SCRIPT_DIR/start-vpn.sh" all
echo
"$SCRIPT_DIR/check-ip.sh"
echo
echo "Migration complete. Open a browser with, for example: ./vpn-sandbox/open-browser.sh poland"
