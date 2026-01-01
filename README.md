# Raspberry Pi Kiosk Setup

Turn a Raspberry Pi 3 into a fullscreen web kiosk that displays a website on a touchscreen or monitor.

## What You'll Need

| Item | Notes |
|------|-------|
| Raspberry Pi 3 Model B | Other Pi models may work but are untested |
| microSD card | 8GB minimum, 16GB+ recommended |
| Power supply | 5V 2.5A micro USB |
| Display | HDMI monitor or official Pi touchscreen |
| Computer | For flashing the SD card |
| WiFi network | SSID and password |

## Quick Start

1. Flash SD card with Raspberry Pi Imager
2. Run `./setup-kiosk.sh "https://your-url.com"`
3. Insert SD card into Pi and power on
4. Wait 5-10 minutes for automatic setup

## Detailed Instructions

### Step 1: Install Raspberry Pi Imager On Your Normal Laptop

Download Raspberry Pi Imager directly from: https://www.raspberrypi.com/software/

### Step 2: Flash the SD Card

1. Insert your microSD card into your Normal Laptop
2. Open **Raspberry Pi Imager** (from Applications or Spotlight)
3. Click **CHOOSE DEVICE** → Select **Raspberry Pi 3**
4. Click **CHOOSE OS** → **Raspberry Pi OS (other)** → **Raspberry Pi OS Lite (32-bit)**
5. Click **CHOOSE STORAGE** → Select your microSD card
6. Click **NEXT**
7. Click **EDIT SETTINGS** and configure:

#### General Tab
| Setting | Value |
|---------|-------|
| Hostname | `kiosk` (or your preference) |
| Username | `pi` |
| Password | `admin` (or your preference) |
| Configure wireless LAN | ✓ Check this |
| SSID | Your WiFi network name |
| Password | Your WiFi password |
| Wireless LAN country | Your country code (e.g., US) |
| Set locale settings | ✓ Check this |
| Time zone | Your timezone |
| Keyboard layout | `us` (or your layout) |

#### Services Tab
| Setting | Value |
|---------|-------|
| Enable SSH | ✓ Check this |
| Use password authentication | ● Select this |

8. Click **SAVE**
9. Click **YES** to apply OS customization settings
10. Click **YES** to confirm erasing the SD card
11. Wait for the write and verification to complete
12. Click **CONTINUE** when done

### Step 3: Run the Kiosk Setup Script

1. **Remove and re-insert** the microSD card (it will mount as "bootfs")
2. Open Terminal and navigate to this folder:
   ```bash
   cd /path/to/Rpi-kiosk
   ```
3. Run the setup script with your kiosk URL:
   ```bash
   ./setup-kiosk.sh "https://your-website-url.com"
   ```

   Or use the default URL:
   ```bash
   ./setup-kiosk.sh
   ```

4. The script will configure the SD card and automatically eject it

### Step 4: Boot the Raspberry Pi

1. Remove the microSD card from your computer
2. Insert it into the Raspberry Pi
3. Connect your display (HDMI or touchscreen)
4. Connect power to the Pi

### Step 5: Wait for First Boot Setup

The first boot takes **5-10 minutes**. The Pi will:

1. Boot and connect to WiFi
2. Download and install required packages (~200MB)
3. Configure the kiosk environment
4. Automatically reboot
5. Launch Chromium in fullscreen kiosk mode

**Be patient!** The screen may be black or show a terminal during this process.

## After Setup

### SSH Access

Connect to your Pi remotely:
```bash
ssh pi@kiosk.local
```
Enter your password when prompted.

If `kiosk.local` doesn't work, find the Pi's IP address on your router and use:
```bash
ssh pi@192.168.x.x
```

### Useful Commands

| Command | Description |
|---------|-------------|
| `sudo systemctl restart lightdm` | Restart the browser |
| `sudo reboot` | Reboot the Pi |
| `sudo poweroff` | Shut down the Pi |
| `sudo nano /etc/xdg/openbox/autostart` | Edit kiosk URL |

### Changing the Kiosk URL

1. SSH into the Pi
2. Edit the autostart file:
   ```bash
   sudo nano /etc/xdg/openbox/autostart
   ```
3. Change the URL in the `chromium` command
4. Save: `Ctrl+O`, `Enter`, `Ctrl+X`
5. Restart the display:
   ```bash
   sudo systemctl restart lightdm
   ```

## Troubleshooting

### Screen is black after first boot
- **Wait longer** - first boot can take 10+ minutes
- SSH in and check cloud-init status:
  ```bash
  ssh pi@kiosk.local
  sudo cloud-init status
  ```
- If status is `running`, wait for it to complete

### WiFi not connecting
- Verify SSID and password are correct
- Re-flash the SD card and double-check WiFi settings in Imager

### Display shows terminal instead of browser
- SSH in and check if packages installed:
  ```bash
  dpkg -l | grep chromium
  ```
- If not installed, run:
  ```bash
  sudo apt update && sudo apt install -y chromium
  sudo systemctl restart lightdm
  ```

### Screen is black but Pi is running (SSH works)
This is usually a display driver issue on Pi 3. Fix it:
```bash
sudo sed -i 's/vc4-kms-v3d/vc4-fkms-v3d/' /boot/firmware/config.txt
sudo reboot
```

### Browser shows but website doesn't load
- Check internet connectivity:
  ```bash
  ping -c 3 google.com
  ```
- Verify the URL is accessible:
  ```bash
  curl -I https://your-url.com
  ```

### Exit kiosk mode temporarily
- Connect a keyboard and press `Alt+F4`
- Or SSH in and run:
  ```bash
  sudo systemctl stop lightdm
  ```

## Files in This Repository

| File | Description |
|------|-------------|
| `setup-kiosk.sh` | Main setup script - configures SD card for kiosk mode |
| `README.md` | This file |

## Technical Details

### Software Stack
- **OS**: Raspberry Pi OS Lite (32-bit, Debian Bookworm)
- **Display Manager**: LightDM with auto-login
- **Window Manager**: Openbox (minimal)
- **Browser**: Chromium in kiosk mode
- **Display Driver**: vc4-fkms-v3d (legacy, for Pi 3 compatibility)

### Chromium Flags Used
| Flag | Purpose |
|------|---------|
| `--kiosk` | Fullscreen mode, no browser UI |
| `--noerrdialogs` | Suppress error dialogs |
| `--disable-infobars` | Hide info bars |
| `--disable-session-crashed-bubble` | No crash recovery prompts |
| `--disable-restore-session-state` | Don't restore previous session |
| `--autoplay-policy=no-user-gesture-required` | Allow auto-playing media |

### Screen Power Management
The kiosk disables screen blanking and power management:
```bash
xset s off          # Disable screensaver
xset s noblank      # Don't blank the screen
xset -dpms          # Disable power management
```

## Security Notes

- Change the default password (`admin`) to something secure
- Consider setting up SSH key authentication instead of passwords
- The kiosk URL should use HTTPS when possible
- For public kiosks, consider additional hardening

## License

MIT License - Use freely for any purpose.
