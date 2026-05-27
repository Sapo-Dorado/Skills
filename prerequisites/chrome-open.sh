#!/usr/bin/env bash
# Ensures Chrome is running on the sapo_hub Xvfb display (:99).

DISPLAY_NUM=99
CHROME_PROFILE=/var/lib/sapo_hub/.config/google-chrome
XDG_RUNTIME=/var/lib/sapo_hub/tmp/runtime
CHROME=/run/current-system/sw/bin/google-chrome-stable
LOG=/var/lib/sapo_hub/tmp/chrome-open.log

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

chrome_running() {
  local lock="${CHROME_PROFILE}/SingletonLock"
  [ -L "$lock" ] || return 1
  local pid
  pid=$(readlink "$lock" | grep -o '[0-9]*$')
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

mkdir -p /var/lib/sapo_hub/tmp
log "chrome-open started."

if chrome_running; then
  log "Chrome already running, exiting."
  exit 0
fi

log "Chrome not running. Clearing lock files..."
rm -f "${CHROME_PROFILE}/SingletonLock" \
      "${CHROME_PROFILE}/SingletonCookie" \
      "${CHROME_PROFILE}/SingletonSocket"

mkdir -p "$XDG_RUNTIME"
log "Launching Chrome..."
XDG_RUNTIME_DIR="$XDG_RUNTIME" \
DISPLAY=":${DISPLAY_NUM}" \
"$CHROME" \
  --user-data-dir="$CHROME_PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  --disable-gpu \
  --disable-software-rasterizer \
  >> /var/lib/sapo_hub/tmp/chrome.log 2>&1 &

CHROME_PID=$!
log "Chrome launched with PID ${CHROME_PID}"

for i in $(seq 1 30); do
  sleep 1
  if kill -0 "$CHROME_PID" 2>/dev/null; then
    log "Chrome alive after ${i}s (PID ${CHROME_PID})."
    exit 0
  fi
  log "Waiting for Chrome... ${i}s"
done

log "ERROR: Chrome PID ${CHROME_PID} not alive after 30s"
log "Last chrome.log: $(tail -3 /var/lib/sapo_hub/tmp/chrome.log 2>/dev/null)"
echo "ERROR: Chrome failed to start" >&2
exit 1
