#!/bin/bash

echo "🔧 Fixing browser container with updated flags..."

# Stop current containers
echo "Stopping containers..."
docker compose down

# Remove old kiosk image to force rebuild
echo "Removing old kiosk image..."
docker rmi kupalovmuhammadjo/turniket-kiosk:latest 2>/dev/null || true
docker rmi turniket-kiosk:latest 2>/dev/null || true

# Rebuild kiosk container with no cache
echo "Rebuilding kiosk container..."
docker compose build --no-cache kiosk

# Tag and push the updated image
echo "Tagging and pushing updated image..."
docker tag minipc_init_kiosk:latest kupalovmuhammadjo/turniket-kiosk:latest
docker push kupalovmuhammadjo/turniket-kiosk:latest

# Start containers
echo "Starting containers..."
docker compose up -d

echo "✅ Browser container updated with --no-sandbox flag"
echo "Check logs with: docker compose logs -f turniket-kiosk"