# Bose SoundTouch Hybrid Home Assistant App Repository

This repository is intended to be added to Home Assistant as a custom app repository.
It contains a Home Assistant wrapper for the original Bose SoundTouch Hybrid app:

https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026

## Donations
If you appreciate the app: [Buy me a Beer](https://www.paypal.com/paypalme/pieterverougstraete)

# Installation

## 1. Install **Music Assistant** (preferably as a Home Assistant app)

* Initial Setup: Once MASS is installed go to its web interface and create a long-lived access token, or keep using your existing username and password. A token is preferred for new installs.

* Configure Providers: Add your desired streaming providers (e.g., Local NAS, TuneIn, Spotify, etc.) and configure any local Music Library synchronization options. Examples of synchronization options are on Page 13 in the SoundTouch Hybrid Documentation

* Configure UPnP: Enable the DLNA/UPnP provider, and for each of your SoundTouch speakers ensure you select DLNA as your "Preferred Output Protocol." DLNA is recommended because the Bose SoundTouch Hybrid system’s self-healing logic, latency management, and real-time state synchronization are heavily optimized for DLNA/UPnP. The majority of stabilization regression testing was done with this protocol. See Page 12 in the SoundTouch Hybrid Documentation for an example.

## 2. Add custom app repo in Home Assistant Apps
repo: https://github.com/djfanatix/HA-Bose-Soundtouch

or

[![Open your Home Assistant instance and add this repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fdjfanatix%2FHA-Bose-Soundtouch)

## 3. Make configuration in the app UI.
   - Leave App IP address blank for auto-detection, or enter the HA host LAN IP manually if needed
   - Leave Music Assistant IP blank when it runs as a Home Assistant app, or enter its IP/hostname when it runs elsewhere such as Docker
   - Enter the Music Assistant port. For authentication, use a long-lived token if available, otherwise enter the Music Assistant username and password
   - Add your speakers in the Config UI, or enable speaker auto-discovery and keep manual entries for fixed overrides
   - The app automatically uses the timezone configured in Home Assistant for accurate logs

## 4. Force Speakers to use Bose Hybrid instead of BOSE Cloud
See https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026
