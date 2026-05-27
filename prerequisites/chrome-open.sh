#!/usr/bin/env bash
# Ensures Chrome is running on the sapo_hub Xvfb display (:99).

DISPLAY_NUM=99
CHROME_PROFILE=/var/lib/sapo_hub/.config/google-chrome
XDG_RUNTIME=/var/lib/sapo_hub/tmp/runtime
CHROME=/run/current-system/sw/bin/google-chrome-stable
LOG=/var/lib/sapo_hub/tmp/chrome-open.log

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

mkdir -p /var/lib/sapo_hub/tmp
log "chrome-open started. PATH=$PATH"
log "Chrome binary: $CHROME (exists: $(test -f "$CHROME" && echo yes || echo NO))"
log "Xvfb display :${DISPLAY_NUM}: $(DISPLAY=:${DISPLAY_NUM} xdpyinfo 2>/dev/null | head -1 || echo 'not available')"

if pgrep -f "google-chrome.*${CHROME_PROFILE}" > /dev/null 2>&1; then
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
  alive=$(ps -p "$CHROME_PID" > /dev/null 2>&1 && echo "yes" || echo "no")
  pgrep_result=$(pgrep -f "google-chrome.*${CHROME_PROFILE}" 2>/dev/null | tr '\n' ' ')
  log "${i}s: PID ${CHROME_PID} alive=${alive} pgrep=[${pgrep_result}]"
  if [ -n "$pgrep_result" ]; then
    log "Chrome detected running after ${i}s."
    exit 0
  fi
done

log "ERROR: Chrome failed to start after 30s"
log "Last chrome.log lines: $(tail -5 /var/lib/sapo_hub/tmp/chrome.log 2>/dev/null)"
echo "ERROR: Chrome failed to start" >&2
exit 1
