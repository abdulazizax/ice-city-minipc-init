#!/bin/bash

# Simple Working Browser Script
# This just starts a browser, no fancy X server management

echo "Starting simple browser..."

# Kill any existing browsers
pkill -f chromium-browser || true
pkill -f turniket-kiosk || true
sleep 2

# Set display
export DISPLAY=:0

# Get URL
URL=${1:-"http://localhost:3000"}

echo "Starting Chromium on $URL"

# Start X server first if not running
if ! xdpyinfo -display :0 >/dev/null 2>&1; then
    echo "Starting X server..."
    sudo X :0 -ac -nolisten tcp -noreset >/dev/null 2>&1 &
    sleep 5
    
    # Wait for X server
    count=0
    while [ $count -lt 10 ]; do
        if xdpyinfo -display :0 >/dev/null 2>&1; then
            echo "X server ready"
            break
        fi
        echo "Waiting for X server... ($count/10)"
        sleep 1
        count=$((count + 1))
    done
else
    echo "X server already running"
fi

# Create user data directory with proper permissions
rm -rf /home/icecity/.config/chromium-kiosk 2>/dev/null
mkdir -p /home/icecity/.config/chromium-kiosk
chmod 755 /home/icecity/.config/chromium-kiosk

# Start Chromium with proper flags
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --no-first-run \
    --disable-infobars \
    --disable-default-apps \
    --disable-extensions \
    --disable-web-security \
    --user-data-dir=/home/icecity/.config/chromium-kiosk \
    --no-default-browser-check \
    --disable-popup-blocking \
    "$URL" &

echo "Browser started"

# Keep script running
while true; do
    sleep 10
    # Check if browser is still running
    if ! pgrep -f chromium-browser > /dev/null; then
        echo "Browser died, restarting..."
        chromium-browser \
            --kiosk \
            --no-sandbox \
            --disable-dev-shm-usage \
            --disable-gpu \
            --no-first-run \
            --disable-infobars \
            --disable-default-apps \
            --disable-extensions \
            --disable-web-security \
            --user-data-dir=/home/icecity/.config/chromium-kiosk \
            --no-default-browser-check \
            --disable-popup-blocking \
            "$URL" &
    fi
done