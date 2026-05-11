# Bose SoundTouch Hybrid Home Assistant App Repository

This repository is intended to be added to Home Assistant as a custom app/add-on repository.
It contains a Home Assistant wrapper for the original Bose SoundTouch Hybrid app:

https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026

# Installation

## 1. Install **Music Assistant** (preferably as Home Assistant APP)

* Initial Setup: Once MASS is installed go to it's web interface to create your login ID and password. These will be used by the SoundTouch Hybrid system to access MASS. (the SoundTouch Hybrid system does not require a MASS "Long-lived Access Token").

* Configure Providers: Add your desired streaming providers (e.g., Local NAS, TuneIn, Spotify, etc.) and configure any local Music Library synchronization options. Examples of synchronization options are on Page 13 in the SoundTouch Hybrid Documentation

* Configure UPnP: Enable the DLNA/UPnP provider, and for each of your SoundTouch speakers ensure you select DLNA as your "Preferred Output Protocol." DLNA is recommended because the Bose SoundTouch Hybrid system’s self-healing logic, latency management, and real-time state synchronization are heavily optimized for DLNA/UPnP. The majority of stabilization regression testing was done with this protocol. See Page 12 in the SoundTouch Hybrid Documentation for an example.

## 2. Add custom App repo in Home Assistant Apps (Addons)
repo: https://github.com/djfanatix/HA-Bose-Soundtouch

or

[![Open your Home Assistant instance and add this repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fdjfanatix%2FHA-Bose-Soundtouch)

## 3. Make configuration in UI of APP.
   - Make sure to enter HA ip address, as this will be used as new Cloud server
   - If you use Music Assistant as App in HA, you can use the URL blank, but you need to add the login and password
   - Add your speakers in the Config UI

## 4. Force Speakers to use Bose Hybrid instead of BOSE Cloud
See https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026
