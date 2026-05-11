# Bose SoundTouch Hybrid Home Assistant App Repository

This repository is intended to be added to Home Assistant as a custom app/add-on repository.

It contains a Home Assistant wrapper for the original Bose SoundTouch Hybrid app:

https://github.com/TJGigs/Bose-SoundTouch-Hybrid-2026

# Installation
1. Install Music Assistant (preferably as Home Assistant APP, configuration according Soundtouch Hybrid Readme
 Setting up Music Assistant (MASS)

Install Music Assistant (MASS): version 2.8.5 or later is required

For installation instructions and troubleshooting, use Music Assistant Help: This includes help for setup, providers, speakers testing, playback issues, etc.

See MASS GitHub
See MASS Website
To run MASS using my specific configuration, I included my mass_docker.yml and mass_package.json files located in the examples subfolder. Your MASS install may or may not be the same but these are provided as reference.
Initial Setup: Once MASS is installed go to it's web interface to create your login ID and password. These will be used by the SoundTouch Hybrid system to access MASS. (the SoundTouch Hybrid system does not require a MASS "Long-lived Access Token").

Configure Providers: Add your desired streaming providers (e.g., Local NAS, TuneIn, Spotify, etc.) and configure any local Music Library synchronization options. Examples of synchronization options are on Page 13 in the SoundTouch Hybrid Documentation

I choose not to enable MASS local library synchronization for my providers to ensure that content search using the SoundTouch Hybrid Library search function (via MASS Search) is directly accessing the most recent data from streaming providers rather than relying on a local MASS cached and periodically sync'd copy. You may decide otherwise.
Configure UPnP: Enable the DLNA/UPnP provider, and for each of your SoundTouch speakers ensure you select DLNA as your "Preferred Output Protocol." DLNA is recommended because the Bose SoundTouch Hybrid system’s self-healing logic, latency management, and real-time state synchronization are heavily optimized for DLNA/UPnP. The majority of stabilization regression testing was done with this protocol. See Page 12 in the SoundTouch Hybrid Documentation for an example.

NOTE: AirPlay is supported but not as fully tested. In the future I'll spend more time testing and optimizing for AirPlay
Very Important: Make sure Music Assistant itself can play audio to your speakers and you hear the audio. Do this completely independent of the Bose SoundTouch Hybrid app. Do this for every provider and speaker you add. This way you know Music Assistant is fully working first before proceeding to install/use the Bose SoundTouch Hybrid system


2. Add custom App repo in Home Assistant Apps (previously called Addons) repo: https://github.com/djfanatix/HA-Bose-Soundtouch
or

[![Open your Home Assistant instance and add this repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fdjfanatix%2FHA-Bose-Soundtouch)

3. Make configuration in UI of APP.
   - Make sure to enter HA ip address, as this will be used as new Cloud server
   - If you use Music Assistant as App in HA, you can use the URL blank, but you need to add the login and password
   - Add your speakers in the Config UI

# Todo
- fix readme
- handle updates and beta versions
