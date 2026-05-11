# Bose SoundTouch Hybrid Home Assistant App

This Home Assistant app packages the original Bose SoundTouch Hybrid Node app without copying the app source into this repository. 

## Configuration

- Set `App IP address` to the LAN IP of the Home Assistant host. Bose speakers must be able to reach this address and the configured app port.

- Leave `App port` at `3010` when using Home Assistant ingress. If you change it, `ingress_port` must be changed to the same value

- When Music Assistant runs as an app/add-on on the same Home Assistant host, leave `Music Assistant IP address` blank. 

- Music Assistant API control uses `Music Assistant username` plus `Music Assistant password`, matching the upstream SoundTouch Hybrid app.
- Add every Bose SoundTouch speaker under `Speakers` with a friendly name and static LAN IP address.


## Upstream Version

The build currently fetches: v3.0.0

## Technical

The Docker build fetches the upstream project from GitHub, then `run.sh` converts Home Assistant app configuration into the files the Node app already expects.

Generated runtime files:

- `/app/config/.env`
- `/app/config/speakers.json`
- `/app/config/library.json`

`/app/config` points at the app's Supervisor-managed `/config` directory, so generated files and library data are visible in the app config folder and included with app backups.

- Repository: `https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026.git`
- Ref: `main`
