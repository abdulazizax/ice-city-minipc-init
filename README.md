# Ice City — MiniPC Init

Provisioning and autostart setup for the Ice City turnstile (turniket) system running on a mini PC. This repo brings up two Docker services — the turnstile **backend** and a Chromium **kiosk** browser displaying the frontend — and keeps them updated automatically via Watchtower.

## System overview

| Service | Image | Purpose |
|---|---|---|
| `backend` | `abdulazizax/turniket:latest` | Turnstile control logic: talks to the gate controller over serial/USB (`/dev/ttyACM*`, `/dev/ttyUSB*`), validates passes against the validator server, serves the frontend on `:8088`. Runs with `network_mode: host` and `privileged: true` for direct device access. |
| `kiosk` | built from [`kiosk/Dockerfile`](kiosk/Dockerfile) | Chromium in kiosk mode, fullscreen, pointed at `http://localhost:8088/frontend/index.html`. Waits for the X server before launching ([`kiosk/entrypoint.sh`](kiosk/entrypoint.sh)). |
| `watchtower` | `containrrr/watchtower` | Polls Docker Hub every 60s and auto-updates/restarts `backend` and `kiosk` when new images are pushed. |

All configuration lives in [`docker-compose.yml`](docker-compose.yml).

## Prerequisites

- A mini PC with **Ubuntu/Debian (Debian 13 "Trixie" recommended)**.
- Physical access to the turnstile network (subnet `192.168.7.0/24`).
- Docker Engine with the Compose v2 plugin (`docker compose`, not the old `docker-compose`).
- The turnstile gate controller connected via USB/serial.

## Full setup — from bare metal to running turnstile

### 1. Install the OS
Install Ubuntu/Debian Server on the mini PC.

### 2. Configure a static IP
Connect the mini PC to the turnstile network and assign it a **free, unused IP** on the `192.168.7.0/24` subnet:

```
Gateway: 192.168.7.10
Mask:    /24 (255.255.255.0)
DNS/Internet: 8.8.8.8
```

The validator server lives at `192.168.7.10` — the backend talks to it directly (see `VALIDATOR_URL` below), so the mini PC must be reachable on this subnet.

### 3. Reboot
Reboot after applying the static IP so the network settings persist correctly.

### 4. Verify connectivity
```bash
ping 8.8.8.8
```

### 5. Update the system
```bash
sudo apt update && sudo apt upgrade -y
```

### 6. Install Git
```bash
sudo apt install -y git
```

### 7. Clone the repository
Open a browser and navigate to the repository on GitHub:

![Navigate to the repo](kiosk/1.jpg)

Open the repo page, click the green **Code** button:

![Repository page](kiosk/2.png)

Copy the HTTPS clone URL:

![Copy clone URL](kiosk/3.png)

Then clone it on the mini PC, pasting the URL you copied above:

```bash
mkdir -p ~/icecity && cd ~/icecity
git clone <paste-the-copied-url-here> .
```

### 8. Run the setup script
Runs system provisioning: installs Docker and dependencies, sets up user permissions, and installs the `minipc-init` systemd service so the stack starts on every boot.

```bash
sudo chmod +x setup.sh
sudo ./setup.sh
```

### 9. Reboot again
So Docker, group permissions, and the systemd service take effect.

### 10. Bring the stack up
After reboot, from the project directory:

```bash
docker compose pull && docker compose up -d
```

The turnstile is now live. From this point on, the `minipc-init` systemd service (see below) takes over and keeps it running across reboots.

## Configuration (`.env`)

Create a `.env` file next to `docker-compose.yml` to override defaults:

```bash
VALIDATOR_URL=http://192.168.7.10:8080
VALIDATOR_TOKEN=
NFC_SOURCE=none
PSEUDO_ALLOW_ALL=false
GATE_SERIAL_PORT=
MAC_ADDRESS=
```

| Variable | Default | Description |
|---|---|---|
| `VALIDATOR_URL` | `http://192.168.7.10:8080` | Address of the validator/kassa server used to check passes. |
| `VALIDATOR_TOKEN` | *(empty)* | Auth token for the validator API, if required. |
| `NFC_SOURCE` | `none` | NFC reader source, if used. |
| `PSEUDO_ALLOW_ALL` | `false` | Debug/testing flag — allows all passes when `true`. **Never enable in production.** |
| `GATE_SERIAL_PORT` | *(empty)* | Explicit serial port for the gate controller, if auto-detection isn't used. |
| `MAC_ADDRESS` | *(empty)* | Device identifier reported by the backend. |

`autostart.sh` loads `.env` automatically before starting the stack.

## Autostart on boot

Two files wire the stack into systemd so it survives reboots and power loss:

- **[`autostart.sh`](autostart.sh)** — idempotent script that loads `.env`, checks the Docker daemon, runs `docker compose pull` (best-effort) and `docker compose up -d --remove-orphans`, then prunes dangling images.
- **[`minipc-init.service`](minipc-init.service)** — systemd unit that runs `autostart.sh` once on boot, after Docker and networking are up.

### Install the service

```bash
chmod +x ./autostart.sh
sudo cp ./minipc-init.service /etc/systemd/system/minipc-init.service
sudo systemctl daemon-reload
sudo systemctl enable minipc-init.service
sudo systemctl start minipc-init.service
```

> **Note:** Edit `WorkingDirectory`, `ExecStart`, `User`, and `Group` in [`minipc-init.service`](minipc-init.service) to match where you cloned the repo and which user should run it.

### Manual run / update

To pull the latest images and restart the stack at any time:

```bash
./autostart.sh
```

## Automatic updates (Watchtower)

Watchtower is included as a service in `docker-compose.yml`. It checks every 60 seconds for new versions of images labeled `com.centurylinklabs.watchtower.enable=true` (both `backend` and `kiosk` carry this label) and restarts them automatically when a new image is pushed to Docker Hub.

To disable auto-updates, comment out or remove the `watchtower` service in `docker-compose.yml`.

## Useful commands

```bash
# View logs
docker compose logs -f backend
docker compose logs -f kiosk

# Restart a single service
docker compose restart backend

# Check status
docker compose ps

# Stop everything
docker compose down
```

## Repository layout

```
.
├── docker-compose.yml       # backend, kiosk, watchtower services
├── kiosk/
│   ├── Dockerfile           # Chromium kiosk image
│   └── entrypoint.sh        # waits for X server, launches Chromium in kiosk mode
├── autostart.sh             # pulls latest images and (re)starts the stack
├── minipc-init.service      # systemd unit that runs autostart.sh on boot
└── README.md
```
