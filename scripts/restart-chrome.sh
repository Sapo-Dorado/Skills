#!/usr/bin/env bash
# SAPO_SCRIPT_NAME: Restart Chrome

CHROME_PROFILE=/var/lib/sapo_hub/.config/google-chrome
XDG_RUNTIME=/var/lib/sapo_hub/tmp/runtime

pkill -f "google-chrome.*${CHROME_PROFILE}" 2>/dev/null || true
sleep 2

rm -f "${CHROME_PROFILE}/SingletonLock" \
      "${CHROME_PROFILE}/SingletonCookie" \
      "${CHROME_PROFILE}/SingletonSocket"

mkdir -p "$XDG_RUNTIME"
XDG_RUNTIME_DIR="$XDG_RUNTIME" \
DISPLAY=":99" \
google-chrome-stable \
  --user-data-dir="$CHROME_PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  --disable-gpu \
  --disable-software-rasterizer \
  > /var/lib/sapo_hub/tmp/chrome.log 2>&1 &

for i in $(seq 1 30); do
  sleep 1
  pgrep -f "google-chrome.*${CHROME_PROFILE}" > /dev/null 2>&1 && echo "Chrome started successfully." && exit 0
done

echo "ERROR: Chrome failed to start" >&2
exit 1
