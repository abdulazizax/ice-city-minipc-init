#!/bin/bash

echo "🚀 Creating stable browser service..."

# Stop the problematic service
sudo systemctl stop simple-browser.service
sudo systemctl disable simple-browser.service

# Create X server service (runs as root)
sudo tee /etc/systemd/system/x-server.service > /dev/null << 'EOF'
[Unit]
Description=X Server for Browser Display
After=multi-user.target
Wants=multi-user.target

[Service]
Type=forking
User=root
ExecStart=/home/icecity/minipc_init/start-x-root.sh
RemainAfterExit=yes
Restart=no

[Install]
WantedBy=multi-user.target
EOF

# Create browser service (runs as user)
sudo tee /etc/systemd/system/stable-browser.service > /dev/null << 'EOF'
[Unit]
Description=Stable Browser Service for Ubuntu Server
After=x-server.service
Requires=x-server.service
Wants=multi-user.target

[Service]
Type=simple
User=icecity
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 3
ExecStart=/home/icecity/minipc_init/start-browser-user.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Update browser control script
sudo systemctl daemon-reload

echo "✅ Stable services created!"
echo ""
echo "Now try:"
echo "  sudo systemctl enable x-server.service"
echo "  sudo systemctl enable stable-browser.service"
echo "  sudo systemctl start x-server.service"
echo "  sudo systemctl start stable-browser.service"
echo "  sudo systemctl status stable-browser.service"