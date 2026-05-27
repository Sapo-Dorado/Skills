#!/usr/bin/env bash
# Ensures Chrome is running on the sapo_hub Xvfb display (:99).

DISPLAY_NUM=99
CHROME_PROFILE=/var/lib/sapo_hub/.config/google-chrome
XDG_RUNTIME=/var/lib/sapo_hub/tmp/runtime

if pgrep -f "google-chrome.*${CHROME_PROFILE}" > /dev/null 2>&1; then
  exit 0
fi

if ! DISPLAY=":${DISPLAY_NUM}" xdpyinfo > /dev/null 2>&1; then
  Xvfb ":${DISPLAY_NUM}" -screen 0 1920x1080x24 &
  sleep 2
fi

mkdir -p "$XDG_RUNTIME"
XDG_RUNTIME_DIR="$XDG_RUNTIME" \
DISPLAY=":${DISPLAY_NUM}" \
google-chrome-stable \
  --user-data-dir="$CHROME_PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  --disable-gpu \
  --disable-software-rasterizer \
  > /var/lib/sapo_hub/tmp/chrome.log 2>&1 &

for i in $(seq 1 10); do
  sleep 1
  pgrep -f "google-chrome.*${CHROME_PROFILE}" > /dev/null 2>&1 && exit 0
done

echo "ERROR: Chrome failed to start" >&2
exit 1
