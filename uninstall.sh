#!/bin/bash
set -e

echo "Webcam HLS Service Uninstaller"
echo "=============================="
echo

read -p "This will remove the webcam HLS service. Continue? [y/N]: " CONFIRM
[ "$CONFIRM" != "y" ] && exit 1

# Stop services
echo "Stopping services..."
sudo systemctl stop webcam-hls.service 2>/dev/null || true
sudo systemctl stop webcam-http.service 2>/dev/null || true

# Disable services
echo "Disabling services..."
sudo systemctl disable webcam-http.service 2>/dev/null || true

# Remove service files
echo "Removing service files..."
sudo rm -f /etc/systemd/system/webcam-hls.service
sudo rm -f /etc/systemd/system/webcam-http.service
sudo rm -f /etc/udev/rules.d/99-webcam-hls.rules

# Reload systemd and udev
echo "Reloading systemd and udev..."
sudo systemctl daemon-reload
sudo udevadm control --reload-rules

echo
read -p "Remove stream directory (~/.local/share/webcam-stream)? [y/N]: " REMOVE_DIR
if [ "$REMOVE_DIR" == "y" ]; then
    rm -rf "$HOME/.local/share/webcam-stream"
    echo "Stream directory removed."
fi

echo
echo "Uninstallation complete!"
