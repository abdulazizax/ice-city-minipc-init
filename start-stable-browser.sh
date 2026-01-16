#!/bin/bash

# Stable X Server Starter for Ubuntu Server
# This approach uses a different method that works consistently

# Set display
export DISPLAY=:0

# Function to start X server as root (more reliable on Ubuntu Server)
start_x_server_root() {
    echo "Starting X server as root (Ubuntu Server compatible)..."
    
    # Kill any existing X server
    sudo pkill -f "Xvfb.*:0" || true
    sudo pkill -f "Xorg.*:0" || true  
    sudo pkill -f "X.*:0" || true
    sleep 3
    
    # Remove lock files
    sudo rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
    
    # Create socket directory
    sudo mkdir -p /tmp/.X11-unix 2>/dev/null || true
    sudo chmod 1777 /tmp/.X11-unix 2>/dev/null || true
    
    # Start X server as root (this works reliably)
    sudo X :0 -ac -nolisten tcp -noreset >/dev/null 2>&1 &
    
    # Wait for X server
    local count=0
    while [ $count -lt 15 ]; do
        if xdpyinfo -display :0 >/dev/null 2>&1; then
            echo "X server is ready on physical display"
            sleep 2
            # Start openbox as regular user
            DISPLAY=:0 openbox >/dev/null 2>&1 &
            return 0
        fi
        echo "Waiting for X server... ($count/15)"
        sleep 1
        count=$((count + 1))
    done
    
    echo "Failed to start X server"
    return 1
}

# Start X server if not running
if ! xdpyinfo -display :0 >/dev/null 2>&1; then
    if ! start_x_server_root; then
        echo "Cannot start X server, exiting"
        exit 1
    fi
else
    echo "X server already running"
fi

# Get URL
URL=${1:-"http://localhost:3000"}
sleep 2

echo "Starting Chromium browser in kiosk mode on $URL"

# Kill any existing chromium processes
pkill -f chromium-browser || true
sleep 2

# Start Chromium as regular user
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

echo "Stable Chromium browser started"

# Keep the script running
wait