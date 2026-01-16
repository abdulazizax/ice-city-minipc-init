#!/bin/bash

# Production Deployment Script for New Servers
echo "🚀 Deploying Turniket system on production server..."

# Install graphics packages for browser display
echo "Installing graphics packages for browser display..."
./setup_remote_browser.sh

# Configure display to stay always on
echo "Configuring display to stay always on..."
./keep-display-on.sh

# Set up X server service
echo "Setting up X server service..."
sudo systemctl enable x-server-setup.service
sudo systemctl start x-server-setup.service

# 2. Configure X server permissions
echo "Configuring X server permissions..."
sudo tee /etc/X11/Xwrapper.config > /dev/null << 'EOF'
allowed_users=anybody
needs_root_rights=yes
EOF

# 3. Create systemd service for X server startup
echo "Creating X server service..."
sudo tee /etc/systemd/system/turniket-xserver.service > /dev/null << 'EOF'
[Unit]
Description=X Server for Turniket Kiosk
After=multi-user.target
Before=docker.service

[Service]
Type=forking
User=root
ExecStart=/usr/bin/X :0 -ac -nolisten tcp -noreset
ExecStop=/usr/bin/pkill -f "X.*:0"
RemainAfterExit=yes
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 4. Enable X server service
sudo systemctl daemon-reload
sudo systemctl enable turniket-xserver.service
sudo systemctl start turniket-xserver.service

# 5. Enable Docker to start on boot
sudo systemctl enable docker

# 6. Pull latest images and start services
echo "Starting Turniket services..."
docker compose pull
docker compose up -d

# 7. Enable auto-restart on boot
echo "Setting up auto-restart on boot..."
sudo tee /etc/systemd/system/turniket-system.service > /dev/null << 'EOF'
[Unit]
Description=Turniket Complete System
After=turniket-xserver.service docker.service
Requires=turniket-xserver.service docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/icecity/minipc_init
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=icecity
Group=icecity

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable turniket-system.service

echo "✅ Production deployment complete!"
echo ""
echo "🎯 System is now configured to:"
echo "  - Start X server on boot"
echo "  - Start Docker services on boot"
echo "  - Auto-restart containers if they crash"
echo "  - Display kiosk on physical monitor"
echo ""
echo "📋 Status commands:"
echo "  sudo systemctl status turniket-xserver.service"
echo "  sudo systemctl status turniket-system.service"
echo "  docker compose ps"
echo "  docker compose logs -f kiosk"