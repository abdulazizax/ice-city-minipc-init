#!/usr/bin/env bash
set -euo pipefail

URL=${LAUNCH_URL:-about:blank}
FLAGS=${CHROMIUM_FLAGS:-"--kiosk --no-first-run --no-default-browser-check"}
DISPLAY=${DISPLAY:-:0}

# Resolve X display socket path
_disp_num="${DISPLAY#:}"
_x_socket="/tmp/.X11-unix/X${_disp_num}"

# Try to detect XAUTHORITY if not provided
if [ -z "${XAUTHORITY:-}" ]; then
  for cand in "/home/kiosk/.Xauthority" "/root/.Xauthority"; do
    if [ -f "$cand" ]; then
      export XAUTHORITY="$cand"
      break
    fi
  done
fi

WAIT_FOR_X_TIMEOUT=${WAIT_FOR_X_TIMEOUT:-120}
KIOSK_NO_WAIT=${KIOSK_NO_WAIT:-0}
if [ "$KIOSK_NO_WAIT" = "1" ]; then
  echo "[kiosk] Skipping X wait (KIOSK_NO_WAIT=1) - will retry in loop if not ready." >&2
else
  echo "[kiosk] Waiting for X server DISPLAY=$DISPLAY socket=$_x_socket (XAUTHORITY=${XAUTHORITY:-unset}) timeout=${WAIT_FOR_X_TIMEOUT}s" >&2
  start_ts=$(date +%s)
  elapsed=0
  while [ ! -S "$_x_socket" ]; do
    now=$(date +%s)
    elapsed=$(( now - start_ts ))
    if [ $elapsed -ge $WAIT_FOR_X_TIMEOUT ]; then
      echo "[kiosk][warn] X socket still not present after ${WAIT_FOR_X_TIMEOUT}s. Will continue retrying in background loop." >&2
      break
    fi
    sleep 2
  done
  if [ -S "$_x_socket" ]; then
    echo "[kiosk] X server socket available after ${elapsed:-0} s." >&2
  fi
fi

# Default to using chromium browser path on Debian/Ubuntu
CHROMIUM_BIN="/usr/bin/chromium"
if [ ! -x "$CHROMIUM_BIN" ]; then
  # Fallbacks
  if command -v chromium-browser >/dev/null 2>&1; then
    CHROMIUM_BIN=$(command -v chromium-browser)
  elif command -v google-chrome >/dev/null 2>&1; then
    CHROMIUM_BIN=$(command -v google-chrome)
  elif command -v google-chrome-stable >/dev/null 2>&1; then
    CHROMIUM_BIN=$(command -v google-chrome-stable)
  elif command -v chromium >/dev/null 2>&1; then
    CHROMIUM_BIN=$(command -v chromium)
  fi
fi


echo "[kiosk] Launching browser $CHROMIUM_BIN -> $URL" >&2
echo "[kiosk] Flags: $FLAGS" >&2

# Auto-restart loop
FAIL_COUNT=0
while true; do
  # Ensure user data and cache directories exist
  mkdir -p /home/kiosk/.config/chromium /tmp/chromium-cache || true
  chmod 700 /home/kiosk/.config/chromium || true
  chmod 700 /tmp/chromium-cache || true
  # Re-detect XAUTHORITY each cycle (it might appear after login)
  if [ -z "${XAUTHORITY:-}" ] || [ ! -f "${XAUTHORITY:-}" ]; then
    for cand in "/home/kiosk/.Xauthority" "/root/.Xauthority"; do
      if [ -f "$cand" ]; then
        export XAUTHORITY="$cand"
        echo "[kiosk] Detected XAUTHORITY=$XAUTHORITY before launch" >&2
        break
      fi
    done
  fi
  if [ ! -S "$_x_socket" ]; then
    echo "[kiosk] X socket missing; sleeping 3s before retry (FAIL_COUNT=$FAIL_COUNT)" >&2
    sleep 3
    continue
  fi
  "$CHROMIUM_BIN" $FLAGS "$URL" &
  PID=$!
  wait $PID
  EXIT_CODE=$?
  if [ $EXIT_CODE -ne 0 ]; then
    FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  else
    FAIL_COUNT=0
  fi
  backoff=2
  if [ $FAIL_COUNT -gt 5 ]; then
    backoff=10
  fi
  echo "[kiosk] Browser exited code=$EXIT_CODE fail_count=$FAIL_COUNT. Restarting in ${backoff}s..." >&2
  sleep $backoff
done
