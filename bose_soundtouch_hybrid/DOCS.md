# Bose SoundTouch Hybrid Home Assistant App

This Home Assistant app packages the original Bose SoundTouch Hybrid Node app without copying the app source into this repository. The Docker build fetches the upstream project from GitHub, then `run.sh` converts Home Assistant app configuration into the files the Node app already expects.

Generated runtime files:

- `/app/config/.env`
- `/app/config/speakers.json`
- `/app/config/library.json`

`/app/config` points at the app's Supervisor-managed `/config` directory, so generated files and library data are visible in the app config folder and included with app backups.

## Configuration

Set `App IP address` to the LAN IP of the Home Assistant host. Bose speakers must be able to reach this address and the configured app port.

Leave `App port` at `3010` when using Home Assistant ingress. If you change it, `ingress_port` in `config.yaml` must be changed to the same value and the app rebuilt.

The Bose cloud injection script uses `App IP address` and `App port`, not the browser URL. For example, if Home Assistant is `192.168.1.120` and the app port is `3010`, the injected Bose URLs will use `http://192.168.1.120:3010`.

Add every Bose SoundTouch speaker under `Speakers` with a friendly name and static LAN IP address.

When Music Assistant runs as an app/add-on on the same Home Assistant host, leave `Music Assistant IP address` blank. The wrapper uses `127.0.0.1` for Music Assistant and auto-detects the Music Assistant app/add-on through the Supervisor API.

Music Assistant API control uses `Music Assistant username` plus `Music Assistant password`, matching the upstream SoundTouch Hybrid app.

Restarting Music Assistant uses the Home Assistant Supervisor API. If auto-detection fails, set `Music Assistant app slug` manually, for example `music_assistant`.

Home Assistant update availability is driven by the `version` field in this add-on repository. Bump `config.yaml` version for every add-on repository release, even if the upstream SoundTouch Hybrid app reference has not changed.

## Upstream Version

The build currently fetches:

- Repository: `https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026.git`
- Ref: `main`

For a stable public release, change `APP_REF` in `build.yaml` to a release tag such as `v3`.
