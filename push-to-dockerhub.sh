#!/bin/bash

# Production Deployment Script for Turniket Kiosk
echo "🚀 Preparing for production deployment..."

# 1. Build the updated kiosk image
echo "Building kiosk image..."
docker compose build kiosk

# 2. Push to Docker Hub
echo "Pushing to Docker Hub..."
docker push kupalovmuhammadjo/turniket-kiosk:latest

echo "✅ Image pushed to Docker Hub!"
echo ""
echo "🎯 Now you can deploy on any server with:"
echo "  git clone <repo>"
echo "  cd minipc_init"
echo "  ./deploy-production.sh"