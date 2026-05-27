#!/usr/bin/env bash
# SAPO_SCRIPT_NAME: Restart Chrome

CHROME_PROFILE=/var/lib/sapo_hub/.config/google-chrome
XDG_RUNTIME=/var/lib/sapo_hub/tmp/runtime
CHROME=/run/current-system/sw/bin/google-chrome-stable

# Kill existing Chrome by PID from SingletonLock
if [ -L "${CHROME_PROFILE}/SingletonLock" ]; then
  pid=$(readlink "${CHROME_PROFILE}/SingletonLock" | grep -o '[0-9]*$')
  [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
  sleep 2
fi

rm -f "${CHROME_PROFILE}/SingletonLock" \
      "${CHROME_PROFILE}/SingletonCookie" \
      "${CHROME_PROFILE}/SingletonSocket"

mkdir -p "$XDG_RUNTIME"
XDG_RUNTIME_DIR="$XDG_RUNTIME" \
DISPLAY=":99" \
"$CHROME" \
  --user-data-dir="$CHROME_PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  --disable-gpu \
  --disable-software-rasterizer \
  >> /var/lib/sapo_hub/tmp/chrome.log 2>&1 &

CHROME_PID=$!
for i in $(seq 1 30); do
  sleep 1
  if kill -0 "$CHROME_PID" 2>/dev/null; then
    echo "Chrome started successfully."
    exit 0
  fi
done

echo "ERROR: Chrome failed to start" >&2
exit 1
