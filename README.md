# Bose SoundTouch Hybrid Home Assistant App Repository

This repository is intended to be added to Home Assistant as a custom app/add-on repository.

It contains a Home Assistant wrapper for the original Bose SoundTouch Hybrid app:

https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026

The app source is fetched during Docker build. User configuration is handled through the Home Assistant app configuration UI and written to the `.env` and `speakers.json` files expected by the upstream Node app.

Before publishing, update:

- `repository.yaml` with your GitHub repository URL, name, and maintainer.
- `bose_soundtouch_hybrid/build.yaml` to pin `APP_REF` to the upstream release tag you want to package.
