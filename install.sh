#!/bin/bash
set -e

# Webcam HLS Service Installer
# Streams a USB webcam as HLS for low-latency browser viewing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
DEFAULT_PORT=8080
DEFAULT_STREAM_DIR="$HOME/.local/share/webcam-stream"

echo "Webcam HLS Service Installer"
echo "============================"
echo

# Check for ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Install with: sudo apt install ffmpeg"
    exit 1
fi

# List available video devices
echo "Available video devices:"
for dev in /dev/video*; do
    if [ -e "$dev" ]; then
        name=$(udevadm info --query=property --name="$dev" 2>/dev/null | grep ID_MODEL= | cut -d= -f2)
        index=$(udevadm info --query=property --name="$dev" 2>/dev/null | grep ID_V4L_PRODUCT= | cut -d= -f2)
        echo "  $dev - ${name:-unknown} ${index:-}"
    fi
done
echo

# Get webcam device
read -p "Enter webcam device path [auto-detect]: " DEVICE
if [ -z "$DEVICE" ]; then
    # Try to find a USB webcam by-id path
    DEVICE=$(ls /dev/v4l/by-id/*-video-index0 2>/dev/null | head -1)
    if [ -z "$DEVICE" ]; then
        echo "Error: No webcam found. Please specify device path."
        exit 1
    fi
    echo "Auto-detected: $DEVICE"
fi

# Verify device exists
if [ ! -e "$DEVICE" ]; then
    echo "Error: Device $DEVICE does not exist"
    exit 1
fi

# Get USB vendor/product ID for udev rules
if [[ "$DEVICE" == /dev/v4l/by-id/* ]]; then
    REAL_DEV=$(readlink -f "$DEVICE")
else
    REAL_DEV="$DEVICE"
fi

SYSPATH=$(udevadm info --query=path --name="$REAL_DEV" 2>/dev/null)
VENDOR=$(udevadm info --query=property --name="$REAL_DEV" 2>/dev/null | grep ID_VENDOR_ID= | cut -d= -f2)
PRODUCT=$(udevadm info --query=property --name="$REAL_DEV" 2>/dev/null | grep ID_MODEL_ID= | cut -d= -f2)

if [ -z "$VENDOR" ] || [ -z "$PRODUCT" ]; then
    echo "Warning: Could not detect USB vendor/product ID. Udev auto-start won't work."
    read -p "Continue anyway? [y/N]: " CONTINUE
    [ "$CONTINUE" != "y" ] && exit 1
    VENDOR="0000"
    PRODUCT="0000"
fi

echo "Detected USB ID: $VENDOR:$PRODUCT"

# Get user
USER_NAME=$(whoami)
read -p "Run service as user [$USER_NAME]: " INPUT_USER
[ -n "$INPUT_USER" ] && USER_NAME="$INPUT_USER"

# Get stream directory
read -p "Stream directory [$DEFAULT_STREAM_DIR]: " STREAM_DIR
[ -z "$STREAM_DIR" ] && STREAM_DIR="$DEFAULT_STREAM_DIR"

# Get HTTP port
read -p "HTTP server port [$DEFAULT_PORT]: " PORT
[ -z "$PORT" ] && PORT="$DEFAULT_PORT"

echo
echo "Configuration:"
echo "  Device: $DEVICE"
echo "  USB ID: $VENDOR:$PRODUCT"
echo "  User: $USER_NAME"
echo "  Stream dir: $STREAM_DIR"
echo "  HTTP port: $PORT"
echo

read -p "Install with these settings? [Y/n]: " CONFIRM
[ "$CONFIRM" == "n" ] && exit 1

# Create stream directory
mkdir -p "$STREAM_DIR"

# Copy index.html
cp "$SCRIPT_DIR/index.html" "$STREAM_DIR/"

# Install systemd service
echo "Installing systemd service..."
sed -e "s|__USER__|$USER_NAME|g" \
    -e "s|__STREAM_DIR__|$STREAM_DIR|g" \
    -e "s|__DEVICE__|$DEVICE|g" \
    "$SCRIPT_DIR/webcam-hls.service" | sudo tee /etc/systemd/system/webcam-hls.service > /dev/null

# Install udev rules
echo "Installing udev rules..."
sed -e "s|__VENDOR__|$VENDOR|g" \
    -e "s|__PRODUCT__|$PRODUCT|g" \
    "$SCRIPT_DIR/99-webcam-hls.rules" | sudo tee /etc/udev/rules.d/99-webcam-hls.rules > /dev/null

# Install HTTP server service
echo "Installing HTTP server service..."
cat << EOF | sudo tee /etc/systemd/system/webcam-http.service > /dev/null
[Unit]
Description=Webcam HLS HTTP server
After=network.target

[Service]
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$STREAM_DIR
ExecStart=/usr/bin/python3 -m http.server $PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and udev
echo "Reloading systemd and udev..."
sudo systemctl daemon-reload
sudo udevadm control --reload-rules

# Enable and start HTTP server
sudo systemctl enable webcam-http.service
sudo systemctl start webcam-http.service

# Start webcam service if device is connected
if [ -e "$DEVICE" ]; then
    echo "Starting webcam service..."
    sudo systemctl start webcam-hls.service
fi

echo
echo "Installation complete!"
echo
echo "The webcam service will start automatically when the camera is plugged in."
echo "View the stream at: http://localhost:$PORT/"
echo
echo "Commands:"
echo "  sudo systemctl status webcam-hls.service  - Check streaming status"
echo "  sudo systemctl status webcam-http.service - Check HTTP server status"
echo "  sudo systemctl stop webcam-hls.service    - Stop streaming"
