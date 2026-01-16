#!/bin/bash

echo "🔆 Configuring display to stay always on..."

# Disable screen blanking and power management for X server
echo "Disabling screen saver and power management..."

# Create xorg.conf.d directory if it doesn't exist
sudo mkdir -p /etc/X11/xorg.conf.d/

# Create X11 configuration to disable power management
sudo tee /etc/X11/xorg.conf.d/10-monitor.conf > /dev/null << 'EOF'
Section "ServerLayout"
    Identifier "ServerLayout0"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection

Section "Monitor"
    Identifier "Monitor0"
    Option "DPMS" "false"
EndSection
EOF

# Disable systemd power management
echo "Disabling systemd power management..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Create a service to keep display on after boot
sudo tee /etc/systemd/system/keep-display-on.service > /dev/null << 'EOF'
[Unit]
Description=Keep Display Always On
After=graphical.target
Wants=graphical.target

[Service]
Type=oneshot
Environment=DISPLAY=:0
ExecStart=/bin/bash -c 'export DISPLAY=:0; xset s off; xset -dpms; xset s noblank'
RemainAfterExit=yes
User=root

[Install]
WantedBy=graphical.target
EOF

# Enable the service
sudo systemctl enable keep-display-on.service

# Apply settings immediately if X server is running
if pgrep -x "Xorg" > /dev/null; then
    echo "Applying display settings immediately..."
    export DISPLAY=:0
    xset s off 2>/dev/null || true      # Disable screen saver
    xset -dpms 2>/dev/null || true      # Disable power management
    xset s noblank 2>/dev/null || true  # Disable screen blanking
fi

echo "✅ Display configured to stay always on"
echo "Settings will be applied after next reboot, or restart X server"
echo ""
echo "To verify settings after reboot:"
echo "  xset q | grep -A 5 'Screen Saver'"
echo "  xset q | grep -A 3 'DPMS'"