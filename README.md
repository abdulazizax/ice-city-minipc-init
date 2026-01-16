# minipc_init

Autostart a Docker Compose stack on boot and fetch updates from Docker Hub if available.

## What this does
- Starts `backend` and `kiosk` services on boot.
- Pulls latest images before starting (manual and on boot via script).
- Optional: Watchtower monitors and updates running services automatically.

## One-time setup
1) Ensure Docker Compose v2 is installed (Docker CE comes with `docker compose`).

2) Make the autostart script executable:

```bash
chmod +x ./autostart.sh
```

3) Create and enable a systemd unit (on Linux):

```bash
sudo cp ./minipc-init.service /etc/systemd/system/minipc-init.service
sudo systemctl daemon-reload
sudo systemctl enable minipc-init.service
sudo systemctl start minipc-init.service
```

Note: Adjust `User`, `Group`, and `WorkingDirectory` in the unit file as needed for your host.

## Manual run / update

```bash
./autostart.sh
```

## Watchtower (optional)
Watchtower is included in `docker-compose.yml`. It checks every 5 minutes and restarts services if new images exist. Disable by commenting out the `watchtower` service.

## Environment
Create a `.env` next to `docker-compose.yml` to override defaults like `VALIDATOR_URL`, `VALIDATOR_TOKEN`, etc. The `autostart.sh` will load it automatically.
