# Bose SoundTouch Hybrid Home Assistant App

This Home Assistant app packages the original Bose SoundTouch Hybrid Node app without copying the app source into this repository. The Docker build fetches the upstream project from GitHub, then `run.sh` converts Home Assistant app configuration into the files the Node app already expects.

Generated runtime files:

- `/app/config/.env`
- `/app/config/speakers.json`
- `/app/config/library.json`

`/app/config` points at the app's Supervisor-managed `/config` directory, so generated files and library data are visible in the app config folder and included with app backups.

## Configuration

Set `App IP address` to the LAN IP of the Home Assistant host. Bose speakers must be able to reach this address and the configured app port.

Add every Bose SoundTouch speaker under `Speakers` with a friendly name and static LAN IP address.

The `Music Assistant container name` is only used by the System Tools restart button and startup auto-restart logic. For the Home Assistant Music Assistant app, the container name normally starts with `addon_` and can be copied from the Music Assistant app URL or container list.

## Upstream Version

The build currently fetches:

- Repository: `https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026.git`
- Ref: `main`

For a stable public release, change `APP_REF` in `build.yaml` to a release tag such as `v3`.
