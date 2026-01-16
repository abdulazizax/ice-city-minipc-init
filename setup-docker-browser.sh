#!/bin/bash

echo "🚀 Setting up Docker browser..."

# Build the Docker image
echo "Building Docker kiosk image..."
docker compose build kiosk

echo "✅ Docker image built!"
echo ""
echo "Now you can use:"
echo "  ./browser-control.sh docker-start    # Start Docker browser"
echo "  ./browser-control.sh docker-stop     # Stop Docker browser"
echo "  ./browser-control.sh docker-restart  # Restart Docker browser"
echo ""
echo "To switch between native and Docker:"
echo "  ./browser-control.sh stop && ./browser-control.sh docker-start  # Native → Docker"
echo "  ./browser-control.sh docker-stop && ./browser-control.sh start  # Docker → Native"