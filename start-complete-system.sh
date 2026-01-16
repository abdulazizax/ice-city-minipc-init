#!/bin/bash

# Complete Setup Script for Ubuntu Server Browser Kiosk
echo "🚀 Setting up complete browser kiosk system..."

# 1. Start X server
echo "Starting X server..."
sudo pkill -f "X.*:0" || true
sleep 2
sudo X :0 -ac -nolisten tcp -noreset >/dev/null 2>&1 &
sleep 5

# 2. Verify X server
if xdpyinfo -display :0 >/dev/null 2>&1; then
    echo "✅ X server is running"
else
    echo "❌ X server failed to start"
    exit 1
fi

# 3. Build Docker images
echo "Building Docker images..."
docker compose build

# 4. Start all services
echo "Starting all services..."
docker compose up -d

echo "✅ Complete setup finished!"
echo ""
echo "Your system is now running:"
echo "  - Backend API on :8088"
echo "  - Browser kiosk on physical display"
echo "  - Watchtower for auto-updates"
echo ""
echo "Commands:"
echo "  docker compose logs -f kiosk     # View kiosk logs"
echo "  docker compose logs -f backend  # View backend logs"
echo "  docker compose down             # Stop everything"
echo "  docker compose up -d            # Start everything"