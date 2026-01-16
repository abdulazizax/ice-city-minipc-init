#!/bin/bash

# Simple headless browser starter - NO D-Bus, NO turniket-kiosk
# This script ONLY uses Chromium to avoid all D-Bus issues

# Set display
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb
export GDK_BACKEND=x11

# Function to start X server for physical display
start_x_server() {
    echo "Starting X server for physical display..."
    
    # Kill any existing X server
    pkill -f "Xvfb.*:0" || true
    pkill -f "Xorg.*:0" || true
    pkill -f "X.*:0" || true
    sleep 3
    
    # Remove lock files
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
    
    # Create socket directory
    mkdir -p /tmp/.X11-unix 2>/dev/null || true
    chmod 1777 /tmp/.X11-unix 2>/dev/null || true
    
    # Try different X server startup methods
    echo "Trying method 1: startx..."
    if startx -- :0 vt1 -keeptty 2>/dev/null &
    then
        sleep 5
        if xdpyinfo -display :0 >/dev/null 2>&1; then
            echo "X server started with startx"
            DISPLAY=:0 openbox >/dev/null 2>&1 &
            return 0
        fi
    fi
    
    echo "Trying method 2: direct X server..."
    pkill -f "X.*:0" || true
    sleep 2
    
    # Try with different options
    X :0 -ac -nolisten tcp -noreset 2>/tmp/x.log &
    
    # Wait for X server
    local count=0
    while [ $count -lt 10 ]; do
        if xdpyinfo -display :0 >/dev/null 2>&1; then
            echo "X server is ready on physical display"
            sleep 2
            DISPLAY=:0 openbox >/dev/null 2>&1 &
            
            # Configure display to stay always on
            echo "Configuring display to stay always on..."
            sleep 2
            DISPLAY=:0 xset s off 2>/dev/null || true      # Disable screen saver
            DISPLAY=:0 xset -dpms 2>/dev/null || true      # Disable power management  
            DISPLAY=:0 xset s noblank 2>/dev/null || true  # Disable screen blanking
            
            return 0
        fi
        echo "Waiting for X server... ($count/10)"
        sleep 1
        count=$((count + 1))
    done
    
    echo "Failed to start X server. Check /tmp/x.log for errors"
    cat /tmp/x.log 2>/dev/null || true
    return 1
}

# Start X server if not running
if ! xdpyinfo -display :0 >/dev/null 2>&1; then
    if ! start_x_server; then
        echo "Cannot start X server, exiting"
        exit 1
    fi
else
    echo "X server already running"
fi

# Get URL
URL=${1:-"http://localhost:3000"}
sleep 2

# Choose browser (uncomment the one you want)
echo "Starting browser in kiosk mode on $URL"

# Kill any existing browser processes
pkill -f chromium-browser || true
pkill -f turniket-kiosk || true
sleep 2

# Option 1: Use turniket-kiosk (may have D-Bus issues)
# DISPLAY=:0 turniket-kiosk --kiosk --no-sandbox --disable-dev-shm-usage --disable-gpu "$URL" &

# Option 2: Use Chromium (recommended - stable)
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

echo "Simple Chromium browser started"

# Keep the script running
wait