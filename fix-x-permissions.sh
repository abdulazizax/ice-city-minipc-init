#!/bin/bash

# Fix X server permissions for Ubuntu Server
echo "🔧 Fixing X server permissions for Ubuntu Server..."

# Add user to required groups
echo "Adding user to required groups..."
sudo usermod -a -G tty,video,input,render icecity

# Allow X server to be started by any user (for kiosk setups)
echo "Configuring X server permissions..."
sudo dpkg-reconfigure -p critical x11-common

# Alternative: Create X11 wrapper configuration
echo "Creating X11 wrapper configuration..."
sudo tee /etc/X11/Xwrapper.config > /dev/null << 'EOF'
# Xwrapper.config (Debian X Window System server wrapper configuration file)
allowed_users=anybody
needs_root_rights=yes
EOF

# Set console permissions
echo "Setting console permissions..."
sudo chmod +s /usr/bin/Xorg
sudo chmod 4755 /usr/bin/Xorg

# Create systemd override to run as console user
echo "Creating systemd service override..."
sudo mkdir -p /etc/systemd/system/simple-browser.service.d
sudo tee /etc/systemd/system/simple-browser.service.d/override.conf > /dev/null << 'EOF'
[Service]
# Run on console for X server access
TTYPath=/dev/tty1
StandardInput=tty-force
StandardOutput=tty
StandardError=tty
EOF

# Reload systemd and try again
sudo systemctl daemon-reload

echo "✅ X server permissions fixed!"
echo ""
echo "Now try:"
echo "  sudo systemctl restart simple-browser.service"
echo "  ./browser-control.sh status"