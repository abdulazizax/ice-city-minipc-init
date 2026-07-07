#!/bin/bash

# MiniPC Complete Setup Script for Turnstile System
# Xubuntu Linux | Docker + Auto-login + Cursor hide + Screen always on + USB-TTL serial
#
# Usage: chmod +x setup.sh && sudo ./setup.sh

set -e

USERNAME=${SUDO_USER:-$(whoami)}
HOME_DIR=$(eval echo ~$USERNAME)

echo "========================================="
echo "  MiniPC Turnstile Setup"
echo "========================================="
echo "  User: $USERNAME"
echo "  Home: $HOME_DIR"
echo "========================================="
echo ""

# ─────────────────────────────────────────────
# 1. SYSTEM UPDATE
# ─────────────────────────────────────────────
echo "[1/6] Updating system..."
apt update
apt upgrade -y

# ─────────────────────────────────────────────
# 2. DOCKER & DOCKER COMPOSE
# ─────────────────────────────────────────────
echo ""
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
  echo "[2/6] Docker already installed, skipping..."
  echo "  Docker: $(docker --version)"
  echo "  Compose: $(docker compose version)"
else
  echo "[2/6] Installing Docker & Docker Compose..."

  apt install -y ca-certificates curl gnupg lsb-release

  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable docker
  systemctl start docker

  echo "  Docker: $(docker --version)"
  echo "  Compose: $(docker compose version)"
fi

usermod -a -G docker $USERNAME

# ─────────────────────────────────────────────
# 3. AUTO-LOGIN (LightDM)
# ─────────────────────────────────────────────
echo ""
echo "[3/6] Configuring auto-login (no password on boot)..."

mkdir -p /etc/lightdm/lightdm.conf.d

tee /etc/lightdm/lightdm.conf.d/50-autologin.conf > /dev/null <<EOF
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
autologin-session=xubuntu
EOF

# ─────────────────────────────────────────────
# 4. HIDE CURSOR & DISABLE SCREEN OFF
# ─────────────────────────────────────────────
echo ""
echo "[4/6] Configuring cursor hide & screen always on..."

apt install -y unclutter

mkdir -p "$HOME_DIR/.config/autostart"

# unclutter: hides cursor after 0.1s of inactivity
cat > "$HOME_DIR/.config/autostart/unclutter.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Unclutter
Comment=Hide cursor when idle
Exec=unclutter -idle 0.1 -root
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# xset: disable DPMS and screen blanking
cat > "$HOME_DIR/.config/autostart/disable-dpms.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Disable DPMS
Comment=Disable screen blanking and power management
Exec=sh -c "xset s off && xset -dpms && xset s noblank"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown -R $USERNAME:$USERNAME "$HOME_DIR/.config/autostart"

# ─────────────────────────────────────────────
# 5. DISABLE LOCK SCREEN & SCREENSAVER
# ─────────────────────────────────────────────
echo ""
echo "[5/6] Disabling lock screen, screensaver, and power management..."

XFCONF_DIR="$HOME_DIR/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCONF_DIR"

# Power manager: disable all screen blanking and DPMS
cat > "$XFCONF_DIR/xfce4-power-manager.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="blank-on-battery" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="dpms-on-battery-sleep" type="uint" value="0"/>
    <property name="dpms-on-battery-off" type="uint" value="0"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
    <property name="dpms-sleep-mode" type="string" value=""/>
  </property>
</channel>
EOF

# Screensaver: disable completely
cat > "$XFCONF_DIR/xfce4-screensaver.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
    <property name="mode" type="int" value="0"/>
  </property>
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
    <property name="saver-activation" type="bool" value="false"/>
  </property>
</channel>
EOF

chown -R $USERNAME:$USERNAME "$XFCONF_DIR"

# Mask screensaver service so it cannot start
systemctl mask xfce4-screensaver.service 2>/dev/null || true

# Also remove xfce4-screensaver package if installed
apt remove -y xfce4-screensaver 2>/dev/null || true

# ─────────────────────────────────────────────
# 6. USB-TTL SERIAL PORT (Arduino / CH340)
# ─────────────────────────────────────────────
echo ""
echo "[6/7] Configuring USB-TTL serial port for Arduino..."

# Remove brltty (it grabs the serial port)
systemctl stop brltty-udev.service 2>/dev/null || true
systemctl mask brltty-udev.service 2>/dev/null || true
systemctl stop brltty.service 2>/dev/null || true
systemctl disable brltty.service 2>/dev/null || true
apt remove -y brltty 2>/dev/null || true

# Remove ModemManager (it grabs serial ports for ~30s on plug)
systemctl stop ModemManager.service 2>/dev/null || true
systemctl disable ModemManager.service 2>/dev/null || true
systemctl mask ModemManager.service 2>/dev/null || true
apt remove -y modemmanager 2>/dev/null || true

apt autoremove -y

# Add user to serial groups
usermod -a -G dialout $USERNAME
usermod -a -G tty $USERNAME

# Auto-load USB serial drivers on boot
tee /etc/modules-load.d/usb-serial.conf > /dev/null <<EOF
usbserial
ch341
ftdi_sio
cp210x
pl2303
EOF

# Load drivers now
modprobe usbserial 2>/dev/null || true
modprobe ch341 2>/dev/null || true
modprobe ftdi_sio 2>/dev/null || true
modprobe cp210x 2>/dev/null || true
modprobe pl2303 2>/dev/null || true

# Udev rules for serial port permissions + persistent symlinks + disable USB autosuspend
tee /etc/udev/rules.d/50-usb-serial.rules > /dev/null <<'EOF'
# === DISABLE USB AUTOSUSPEND FOR ALL USB DEVICES ===
ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="-1"
ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend_delay_ms}="-1"

# === PERSISTENT SYMLINK: /dev/turniket-gate ===
# CH340/CH341 (most common USB-TTL for Arduino)
KERNEL=="ttyUSB*", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="turniket-gate", MODE="0666", GROUP="dialout"
# FTDI
KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="turniket-gate", MODE="0666", GROUP="dialout"
# CP210x
KERNEL=="ttyUSB*", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="turniket-gate", MODE="0666", GROUP="dialout"
# Arduino ACM (native USB)
KERNEL=="ttyACM*", ATTRS{idVendor}=="2341", SYMLINK+="turniket-gate", MODE="0666", GROUP="dialout"

# Generic permissions
SUBSYSTEM=="tty", GROUP="dialout", MODE="0660"
KERNEL=="ttyUSB[0-9]*", MODE="0666"
KERNEL=="ttyACM[0-9]*", MODE="0666"
EOF

udevadm control --reload-rules
udevadm trigger

# ─────────────────────────────────────────────
# 7. DISABLE USB AUTOSUSPEND (GLOBAL)
# ─────────────────────────────────────────────
echo ""
echo "[7/7] Disabling USB autosuspend globally..."

# Disable USB autosuspend immediately
echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true

# Disable for all currently connected USB devices
for dev in /sys/bus/usb/devices/*/power/control; do
  echo "on" > "$dev" 2>/dev/null || true
done
for dev in /sys/bus/usb/devices/*/power/autosuspend; do
  echo -1 > "$dev" 2>/dev/null || true
done

# Add kernel boot parameter to permanently disable USB autosuspend
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
  if ! grep -q "usbcore.autosuspend=-1" "$GRUB_FILE"; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 usbcore.autosuspend=-1"/' "$GRUB_FILE"
    update-grub
    echo "  GRUB updated with usbcore.autosuspend=-1"
  else
    echo "  GRUB already has usbcore.autosuspend=-1"
  fi
fi

# Systemd service: ensure USB power stays on after every boot
tee /etc/systemd/system/usb-power-on.service > /dev/null <<'EOF'
[Unit]
Description=Disable USB autosuspend for all devices
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'echo -1 > /sys/module/usbcore/parameters/autosuspend; for d in /sys/bus/usb/devices/*/power/control; do echo on > "$d" 2>/dev/null; done; for d in /sys/bus/usb/devices/*/power/autosuspend; do echo -1 > "$d" 2>/dev/null; done'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable usb-power-on.service
systemctl start usb-power-on.service

# Disable TLP USB autosuspend if TLP is installed
if [ -f /etc/tlp.conf ]; then
  if ! grep -q "USB_AUTOSUSPEND=0" /etc/tlp.conf; then
    echo "USB_AUTOSUSPEND=0" >> /etc/tlp.conf
    echo "  TLP USB autosuspend disabled"
  fi
fi

# ─────────────────────────────────────────────
# 8. USB PORT RECOVERY WATCHDOG
# ─────────────────────────────────────────────
echo ""
echo "[8/8] Installing USB port recovery watchdog..."

tee /usr/local/bin/usb-watchdog.sh > /dev/null <<'SCRIPT'
#!/bin/bash
# USB Port Watchdog: detects when /dev/turniket-gate disappears and rebinds the xHCI controller.
# Runs every 30s. Only acts if the device has been missing for 2 consecutive checks.

GATE_DEV="/dev/turniket-gate"
MISS_COUNT=0
MAX_MISS=2

while true; do
  sleep 30

  if [ -e "$GATE_DEV" ]; then
    MISS_COUNT=0
    continue
  fi

  MISS_COUNT=$((MISS_COUNT + 1))
  logger -t usb-watchdog "Gate device missing ($MISS_COUNT/$MAX_MISS)"

  if [ "$MISS_COUNT" -ge "$MAX_MISS" ]; then
    logger -t usb-watchdog "Rebinding all xhci_hcd controllers..."

    for hci in /sys/bus/pci/drivers/xhci_hcd/????:??:??.?; do
      DEV=$(basename "$hci")
      echo "$DEV" > /sys/bus/pci/drivers/xhci_hcd/unbind 2>/dev/null || true
      sleep 1
      echo "$DEV" > /sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
    done

    sleep 5
    MISS_COUNT=0
    logger -t usb-watchdog "xHCI rebind complete"
  fi
done
SCRIPT

chmod +x /usr/local/bin/usb-watchdog.sh

tee /etc/systemd/system/usb-watchdog.service > /dev/null <<'EOF'
[Unit]
Description=USB Port Recovery Watchdog
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/usb-watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable usb-watchdog.service
systemctl start usb-watchdog.service

# ─────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────
echo ""
echo "========================================="
echo "  Setup completed successfully!"
echo "========================================="
echo ""
echo "  [x] Docker & Docker Compose installed"
echo "  [x] Auto-login enabled (no password)"
echo "  [x] Cursor auto-hide enabled"
echo "  [x] Screen will never turn off"
echo "  [x] Lock screen disabled"
echo "  [x] USB-TTL serial port configured"
echo "  [x] ModemManager removed"
echo "  [x] USB autosuspend disabled (GRUB + systemd + udev)"
echo "  [x] USB port recovery watchdog installed"
echo ""
echo "  REBOOT REQUIRED: sudo reboot"
echo ""
echo "  After reboot, verify:"
echo "    docker run hello-world"
echo "    ls -la /dev/ttyUSB*"
echo "========================================="
