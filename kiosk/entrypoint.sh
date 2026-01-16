#!/bin/bash
set -e

# Wait for X server to be available
echo "Waiting for X server on display ${DISPLAY}..."
timeout=30
count=0

while [ $count -lt $timeout ]; do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
        echo "X server is ready"
        break
    fi
    echo "Waiting for X server... ($count/$timeout)"
    sleep 1
    count=$((count + 1))
done

if [ $count -eq $timeout ]; then
    echo "ERROR: X server not available after ${timeout} seconds"
    exit 1
fi

# Additional wait for X server to fully stabilize
sleep 3

# Use the URL from environment or default
URL="${LAUNCH_URL:-http://localhost:8088/frontend/index.html}"

echo "Starting Chromium browser in kiosk mode..."
echo "URL: $URL"
echo "Display: $DISPLAY"
echo "Chromium flags: $CHROMIUM_FLAGS"

# Create user data directory
mkdir -p /home/kiosk/.config/chromium-docker
chmod 755 /home/kiosk/.config/chromium-docker

# Start Chromium with the specified flags (matching our working native setup)
exec chromium \
    --display="${DISPLAY}" \
    --kiosk \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --no-first-run \
    --disable-infobars \
    --disable-default-apps \
    --disable-extensions \
    --disable-web-security \
    --user-data-dir=/home/kiosk/.config/chromium-docker \
    --no-default-browser-check \
    --disable-popup-blocking \
    --disable-translate \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-field-trial-config \
    --disable-back-forward-cache \
    --disable-ipc-flooding-protection \
    "$URL"