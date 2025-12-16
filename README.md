# Webcam HLS Service

A simple service that streams a USB webcam as HLS (HTTP Live Streaming) for low-latency browser viewing.

## Features

- Auto-starts when webcam is plugged in
- Auto-stops when webcam is unplugged
- Low-latency (~3 seconds) HLS streaming
- Simple web player with cache-busting
- Works with any USB webcam

## Requirements

- Linux with systemd
- ffmpeg
- Python 3 (for HTTP server)
- A USB webcam

## Installation

```bash
# Install ffmpeg if not already installed
sudo apt install ffmpeg

# Run the installer
./install.sh
```

The installer will:
1. Auto-detect your webcam
2. Configure the streaming service
3. Set up udev rules for auto-start/stop
4. Start an HTTP server for the web player

## Usage

Once installed, simply plug in your webcam and open:

```
http://localhost:8080/
```

The stream will start automatically when the camera is connected and stop when disconnected.

## Commands

```bash
# Check streaming status
sudo systemctl status webcam-hls.service

# Check HTTP server status
sudo systemctl status webcam-http.service

# Manually stop streaming
sudo systemctl stop webcam-hls.service

# View logs
journalctl -u webcam-hls.service -f
```

## Uninstallation

```bash
./uninstall.sh
```

## Configuration

The installer creates:
- `/etc/systemd/system/webcam-hls.service` - Streaming service
- `/etc/systemd/system/webcam-http.service` - HTTP server
- `/etc/udev/rules.d/99-webcam-hls.rules` - Auto-start rules
- `~/.local/share/webcam-stream/` - Stream files and web player

## Technical Details

- Video: H.264, 1920x1080, 10fps
- Encoding: ultrafast preset, zerolatency tune
- HLS: 0.5s segments, 2 segment playlist
- Latency: ~3 seconds end-to-end

## License

MIT
