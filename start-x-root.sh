#!/bin/bash

# Root X Server Starter (runs as root)
# This script starts the X server with proper permissions

echo "Starting X server as root..."

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

# Start X server as root
X :0 -ac -nolisten tcp -noreset >/dev/null 2>&1 &

# Wait for X server
count=0
while [ $count -lt 15 ]; do
    if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
        echo "X server is ready on physical display"
        # Start openbox as icecity user
        sudo -u icecity DISPLAY=:0 openbox >/dev/null 2>&1 &
        exit 0
    fi
    echo "Waiting for X server... ($count/15)"
    sleep 1
    count=$((count + 1))
done

echo "Failed to start X server"
exit 1