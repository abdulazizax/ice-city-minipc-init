#!/bin/bash

# User Browser Starter (runs as regular user)
# This script starts the browser after X server is ready

export DISPLAY=:0

# Wait for X server to be available
echo "Waiting for X server..."
count=0
while [ $count -lt 30 ]; do
    if xdpyinfo -display :0 >/dev/null 2>&1; then
        echo "X server is available"
        break
    fi
    echo "Waiting for X server... ($count/30)"
    sleep 1
    count=$((count + 1))
done

if [ $count -eq 30 ]; then
    echo "ERROR: X server not available"
    exit 1
fi

# Get URL
URL=${1:-"http://localhost:3000"}
sleep 2

echo "Starting Chromium browser in kiosk mode on $URL"

# Kill any existing chromium processes
pkill -f chromium-browser || true
sleep 2

# Start Chromium
DISPLAY=:0 chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --no-first-run \
    --disable-infobars \
    --disable-default-apps \
    --disable-extensions \
    --disable-plugins \
    --disable-web-security \
    --disable-features=VizDisplayCompositor,TranslateUI \
    --no-default-browser-check \
    --disable-popup-blocking \
    --disable-translate \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-field-trial-config \
    --disable-back-forward-cache \
    --disable-ipc-flooding-protection \
    "$URL" >/dev/null 2>&1 &

echo "Browser started successfully"

# Keep the script running
wait