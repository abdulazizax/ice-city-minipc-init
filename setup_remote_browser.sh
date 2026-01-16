#!/bin/bash

# Minimal Ubuntu Server Setup for Headless Browser/Kiosk
# This script installs only essential components to run Chromium-based apps

set -e

echo "🚀 Setting up minimal headless browser environment..."

# Update package index
echo "📦 Updating package index..."
sudo apt update

# Install X11 components for physical display
echo "🖥️  Installing X11 server for physical display..."
sudo apt install -y \
    xserver-xorg \
    xserver-xorg-core \
    xserver-xorg-input-all \
    xserver-xorg-video-all \
    xinit \
    x11-utils \
    x11-xserver-utils \
    xauth \
    openbox \
    dbus-x11

# Install essential libraries for Chromium (minimal set)
echo "📚 Installing essential browser libraries..."
sudo apt install -y \
    libgtk-3-0 \
    libnss3 \
    libxss1 \
    libxrandr2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libgdk-pixbuf2.0-0 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxtst6 \
    libxdamage1 \
    libdrm2 \
    libxfixes3 \
    libatspi2.0-0

# Install audio libraries (try multiple options)
echo "🔊 Installing audio libraries..."
sudo apt install -y libasound2-dev || sudo apt install -y alsa-utils || echo "Audio packages not available"

# Install additional compatibility libraries
echo "🔧 Installing compatibility libraries..."
sudo apt install -y \
    libappindicator3-1 \
    libxkbcommon0 \
    libxkbfile1 \
    ca-certificates \
    wget \
    gnupg \
    xdg-utils

# Install a fallback browser if no browser is available
echo "🌐 Installing fallback browser (Chromium)..."
sudo apt install -y chromium-browser || echo "Chromium installation failed, will use available browser"

# Install minimal fonts
echo "� Installing basic fonts..."
sudo apt install -y \
    fonts-liberation \
    fontconfig

# Create headless browser startup script
echo "📝 Creating headless browser script..."
sudo tee /usr/local/bin/start-headless-browser.sh > /dev/null << 'EOF'
#!/bin/bash

# Set display and other environment variables
export DISPLAY=:0
export XAUTHORITY=/tmp/.X0-auth

# Minimal environment setup for Chromium only
export QT_QPA_PLATFORM=xcb
export GDK_BACKEND=x11

# Function to start Xvfb (Virtual X server) properly
start_x_server() {
    echo "Starting Xvfb (Virtual X server)..."
    
    # Kill any existing X server on display :0
    pkill -f "Xvfb.*:0" || true
    pkill -f "X.*:0" || true
    sleep 2
    
    # Remove any existing lock files
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
    
    # Create X11 socket directory if it doesn't exist
    mkdir -p /tmp/.X11-unix 2>/dev/null || true
    chmod 1777 /tmp/.X11-unix 2>/dev/null || true
    
    # Start Xvfb (Virtual framebuffer X server) - works on headless servers
    Xvfb :0 -screen 0 1920x1080x24 -ac -nolisten tcp -dpi 96 +extension GLX +extension RANDR +extension RENDER 2>/dev/null &
    
    # Wait for X server to be ready
    local count=0
    while [ $count -lt 10 ]; do
        if xdpyinfo -display :0 >/dev/null 2>&1; then
            echo "Xvfb is ready"
            return 0
        fi
        echo "Waiting for Xvfb... ($count/10)"
        sleep 1
        count=$((count + 1))
    done
    
    echo "Failed to start Xvfb"
    return 1
}

# Check if X server is running, if not start it
if ! xdpyinfo -display :0 >/dev/null 2>&1; then
    if ! start_x_server; then
        echo "Cannot start X server, exiting"
        exit 1
    fi
else
    echo "X server already running"
fi

# Get the URL from argument or use default
URL=${1:-"http://localhost:3000"}

# Wait a bit more for X server to stabilize
sleep 2

# Skip turniket-kiosk completely - use simple Chromium instead
echo "Starting simple Chromium browser in headless kiosk mode..."

# Force use of Chromium instead of turniket-kiosk to avoid D-Bus issues
if command -v chromium-browser &> /dev/null; then
    echo "Starting Chromium browser in simple kiosk mode on $URL"
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
        --no-first-run-ui \
        --disable-default-apps \
        --disable-popup-blocking \
        --disable-translate \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-field-trial-config \
        --disable-back-forward-cache \
        --disable-ipc-flooding-protection \
        "$URL" &
elif command -v google-chrome &> /dev/null; then
    echo "Starting Google Chrome in kiosk mode on $URL"
    google-chrome \
        --kiosk \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-gpu \
        --disable-software-rasterizer \
        --no-first-run \
        --disable-infobars \
        --disable-default-apps \
        "$URL"
elif command -v firefox &> /dev/null; then
    echo "Starting Firefox in kiosk-like mode on $URL"
    firefox --kiosk "$URL"
else
    echo "❌ No supported browser found!"
    echo "Please install one of the following:"
    echo "  - turniket-kiosk (recommended)"
    echo "  - chromium-browser: sudo apt install chromium-browser"
    echo "  - google-chrome: wget and install from Google"
    echo "  - firefox: sudo apt install firefox"
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/start-headless-browser.sh

# Create systemd service for headless browser
echo "🔧 Creating minimal systemd service..."
sudo tee /etc/systemd/system/headless-browser.service > /dev/null << 'EOF'
[Unit]
Description=Headless Browser Service
After=multi-user.target
Wants=multi-user.target

[Service]
Type=simple
User=icecity
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 10
ExecStart=/usr/local/bin/start-headless-browser.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Minimal headless browser setup completed!"
echo ""
echo "📖 Usage instructions:"
echo "1. Manual start: sudo /usr/local/bin/start-headless-browser.sh [URL]"
echo "2. Enable auto-start: sudo systemctl enable headless-browser.service"
echo "3. Start service now: sudo systemctl start headless-browser.service"
echo ""
echo "🔧 Notes:"
echo "- No desktop environment installed - server stays headless"
echo "- Install turniket-kiosk separately for full functionality"
echo "- X server runs only when browser is active"
echo "- Service runs as user 'icecity' - adjust if needed"
echo "- Edit /usr/local/bin/start-headless-browser.sh to customize"