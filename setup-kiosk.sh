#!/bin/bash
#
# Raspberry Pi Kiosk Setup Script
# ================================
# This script configures a freshly flashed Raspberry Pi OS Lite SD card
# to boot into a fullscreen kiosk browser.
#
# Prerequisites:
#   1. Install Raspberry Pi Imager: brew install --cask raspberry-pi-imager
#   2. Flash "Raspberry Pi OS Lite (32-bit)" to your SD card
#   3. In Imager settings, configure:
#      - Hostname (e.g., "kiosk")
#      - Username: pi, Password: your choice
#      - WiFi SSID and password
#      - Enable SSH with password authentication
#   4. After flashing, re-insert the SD card
#   5. Run this script
#
# Usage:
#   ./setup-kiosk.sh [URL]
#
# Example:
#   ./setup-kiosk.sh "https://example.com/dashboard"
#

set -e

# Default kiosk URL (change this or pass as argument)
DEFAULT_URL="https://orange-dune-06c16eb1e.6.azurestaticapps.net"
KIOSK_URL="${1:-$DEFAULT_URL}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "=========================================="
echo "  Raspberry Pi Kiosk Setup Script"
echo "=========================================="
echo ""

# Check for bootfs volume
BOOTFS="/Volumes/bootfs"
if [ ! -d "$BOOTFS" ]; then
    echo -e "${RED}Error: SD card not found at $BOOTFS${NC}"
    echo ""
    echo "Please ensure you have:"
    echo "  1. Flashed Raspberry Pi OS Lite (32-bit) using Raspberry Pi Imager"
    echo "  2. Configured WiFi and SSH in the Imager settings"
    echo "  3. Re-inserted the SD card after flashing"
    echo ""
    echo "The 'bootfs' volume should appear in Finder."
    exit 1
fi

echo -e "${GREEN}Found SD card at $BOOTFS${NC}"
echo ""

# Check if user-data exists (confirms it's a valid Pi OS image)
if [ ! -f "$BOOTFS/user-data" ]; then
    echo -e "${RED}Error: user-data file not found${NC}"
    echo "This doesn't appear to be a freshly flashed Raspberry Pi OS image."
    echo "Please re-flash with Raspberry Pi Imager."
    exit 1
fi

echo "Kiosk URL: $KIOSK_URL"
echo ""

# Backup original files
echo "Backing up original configuration files..."
cp "$BOOTFS/user-data" "$BOOTFS/user-data.backup"
cp "$BOOTFS/config.txt" "$BOOTFS/config.txt.backup"

# Read existing user-data to preserve user settings
echo "Reading existing configuration..."
EXISTING_HOSTNAME=$(grep "^hostname:" "$BOOTFS/user-data" | cut -d: -f2 | tr -d ' ' || echo "kiosk")
EXISTING_TIMEZONE=$(grep "^timezone:" "$BOOTFS/user-data" | cut -d: -f2- | tr -d ' ' || echo "America/Chicago")
EXISTING_PASSWD=$(grep "passwd:" "$BOOTFS/user-data" | head -1 | sed 's/.*passwd: *//' | tr -d '"' || echo "")

echo "  Hostname: $EXISTING_HOSTNAME"
echo "  Timezone: $EXISTING_TIMEZONE"
echo ""

# Create new user-data with kiosk configuration
echo "Configuring kiosk mode..."
cat > "$BOOTFS/user-data" << 'USERDATA_HEADER'
#cloud-config
manage_resolv_conf: false
USERDATA_HEADER

cat >> "$BOOTFS/user-data" << USERDATA_VARS
hostname: $EXISTING_HOSTNAME
USERDATA_VARS

cat >> "$BOOTFS/user-data" << 'USERDATA_PACKAGES'
manage_etc_hosts: true
packages:
- avahi-daemon
- xserver-xorg
- x11-xserver-utils
- xinit
- openbox
- chromium
- unclutter
- lightdm
apt:
  preserve_sources_list: true
  conf: |
    Acquire {
      Check-Date "false";
    };
USERDATA_PACKAGES

cat >> "$BOOTFS/user-data" << USERDATA_TIMEZONE
timezone: $EXISTING_TIMEZONE
USERDATA_TIMEZONE

cat >> "$BOOTFS/user-data" << 'USERDATA_KEYBOARD'
keyboard:
  model: pc105
  layout: "us"
users:
- name: pi
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  lock_passwd: false
USERDATA_KEYBOARD

# Add password if it exists
if [ -n "$EXISTING_PASSWD" ]; then
    echo "  passwd: \"$EXISTING_PASSWD\"" >> "$BOOTFS/user-data"
fi

cat >> "$BOOTFS/user-data" << 'USERDATA_SSH'
enable_ssh: true
ssh_pwauth: true
rpi:
  interfaces:
    serial: true

write_files:
USERDATA_SSH

# Add autostart file with the kiosk URL
cat >> "$BOOTFS/user-data" << USERDATA_AUTOSTART
- path: /home/pi/.config/openbox/autostart
  owner: pi:pi
  permissions: '0755'
  defer: true
  content: |
    # Disable screen blanking
    xset s off
    xset s noblank
    xset -dpms

    # Hide mouse cursor after 0.5 seconds of inactivity
    unclutter -idle 0.5 -root &

    # Wait for network
    sleep 10

    # Start Chromium in kiosk mode
    chromium --noerrdialogs --disable-infobars --disable-session-crashed-bubble \\
      --disable-restore-session-state --kiosk \\
      --disable-component-update --check-for-update-interval=31536000 \\
      --autoplay-policy=no-user-gesture-required \\
      '$KIOSK_URL'

- path: /home/pi/.config/openbox/environment
  owner: pi:pi
  permissions: '0644'
  defer: true
  content: |
    export DISPLAY=:0

- path: /etc/lightdm/lightdm.conf.d/autologin.conf
  owner: root:root
  permissions: '0644'
  content: |
    [Seat:*]
    autologin-user=pi
    autologin-user-timeout=0
    user-session=openbox

- path: /etc/xdg/openbox/autostart
  owner: root:root
  permissions: '0755'
  content: |
    # Disable screen blanking
    xset s off
    xset s noblank
    xset -dpms

    # Hide mouse cursor
    unclutter -idle 0.5 -root &

    # Wait for network
    sleep 10

    # Start Chromium in kiosk mode
    chromium --noerrdialogs --disable-infobars --disable-session-crashed-bubble \\
      --disable-restore-session-state --kiosk \\
      --disable-component-update --check-for-update-interval=31536000 \\
      --autoplay-policy=no-user-gesture-required \\
      '$KIOSK_URL'

USERDATA_AUTOSTART

cat >> "$BOOTFS/user-data" << 'USERDATA_RUNCMD'
runcmd:
- mkdir -p /home/pi/.config/openbox
- chown -R pi:pi /home/pi/.config
- systemctl set-default graphical.target
- systemctl enable lightdm
- echo "Kiosk setup complete. Rebooting..." && reboot
USERDATA_RUNCMD

# Update config.txt for Pi 3 compatibility (use legacy fkms driver)
echo "Updating display configuration for Pi 3 compatibility..."
sed -i.bak 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-fkms-v3d/' "$BOOTFS/config.txt"

# Add GPU memory and disable splash if not present
if ! grep -q "gpu_mem=" "$BOOTFS/config.txt"; then
    echo "" >> "$BOOTFS/config.txt"
    echo "# GPU memory for smooth browser rendering" >> "$BOOTFS/config.txt"
    echo "gpu_mem=128" >> "$BOOTFS/config.txt"
fi

if ! grep -q "disable_splash=" "$BOOTFS/config.txt"; then
    echo "" >> "$BOOTFS/config.txt"
    echo "# Disable rainbow splash screen for cleaner boot" >> "$BOOTFS/config.txt"
    echo "disable_splash=1" >> "$BOOTFS/config.txt"
fi

echo ""
echo -e "${GREEN}Configuration complete!${NC}"
echo ""

# Safely eject the card
echo "Ejecting SD card..."
diskutil eject "$BOOTFS"

echo ""
echo "=========================================="
echo -e "${GREEN}  Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Remove the SD card from your Mac"
echo "  2. Insert it into the Raspberry Pi 3"
echo "  3. Connect your display and power on"
echo ""
echo "First boot will take 5-10 minutes to:"
echo "  - Connect to WiFi"
echo "  - Download and install kiosk packages"
echo "  - Automatically reboot into kiosk mode"
echo ""
echo "SSH access (after boot):"
echo "  ssh pi@${EXISTING_HOSTNAME}.local"
echo ""
echo "Useful commands:"
echo "  sudo systemctl restart lightdm  # Restart browser"
echo "  sudo nano /etc/xdg/openbox/autostart  # Change URL"
echo "  sudo reboot  # Reboot Pi"
echo ""
