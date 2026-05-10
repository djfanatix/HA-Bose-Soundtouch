# Bose SoundTouch Hybrid Home Assistant App Repository

This repository is intended to be added to Home Assistant as a custom app/add-on repository.

It contains a Home Assistant wrapper for the original Bose SoundTouch Hybrid app:

https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026

# Installation
1. Install Music Assistant (preferably as Home Assistant APP, configuration according Soundtouch Hybrid Readme
2. Add custom App repo in Home Assistant Apps (previously called Addons) repo: https://github.com/djfanatix/HA-Bose-Soundtouch
[![Open your Home Assistant instance and add this repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fdjfanatix%2FHA-Bose-Soundtouch)

3. Make configuration in UI of APP.
   - Make sure to enter HA ip address, as this will be used as new Cloud server
   - If you use Music Assistant as App in HA, you can use the URL blank, but you need to add the login and password
   - Add your speakers in the Config UI

# Todo
- fix readme
- handle updates and beta versions