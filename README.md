<p align="center"><img width="200" height="200" align="center" alt="ablaut logo" src="./app/assets/ablaut-logo.png" /></p>

# ablaut-App

ablaut lets listeners join live translated audio from an [ablaut server](https://github.com/silvansan/ablaut-Studio) deployment.

Scan an ablaut listener QR code, open a saved favorite, or paste a listener link, then listen through your phone or Bluetooth headphones.

## Download (Android)

Install the latest APK from [GitHub Releases](https://github.com/silvansan/ablaut-App/releases/latest):

**[Download app-release.apk](https://github.com/silvansan/ablaut-App/releases/latest/download/app-release.apk)**

After downloading, Android may ask you to allow installation from your browser or file manager. This app is distributed via GitHub (sideload), not the Google Play Store.

Older releases used different APK file names; the current release asset is always **`app-release.apk`** so the link above stays stable.

## Server

This repo is the **mobile listener** companion for the **[ablaut server](https://github.com/silvansan/ablaut-Studio)** — host events, publish live audio channels, and generate listener QR codes there.

| Repo | Role |
|------|------|
| [ablaut-Studio](https://github.com/silvansan/ablaut-Studio) | ablaut server — dashboard, LiveKit/HLS publishing |
| [ablaut-App](https://github.com/silvansan/ablaut-App) | Android / iOS listener app (this repo) |

ablaut remains compatible with listener links from older deployments, including legacy `/e/.../listen` URLs and `undersound://` deep links.

## Features

- Scan listener QR codes (camera or image file).
- Paste or enter a listener URL manually.
- Save favorite channels and reopen them from the home screen.
- Password-protected listener channels (verify with the event listener password, then reconnect with a saved session).
- Low-latency WebRTC (LiveKit) playback with HLS fallback when the server provides it.
- Android media notification controls for play, pause, and mute.
- Pause automatically when headphones or Bluetooth disconnect.

## Privacy

ablaut is built for listening to live event audio. The app does not add advertising or tracking.

Camera access is used only for QR scanning. Listener passwords can be stored locally on your device (encrypted) so you do not have to re-enter them for saved favorites.

## Development

See [app/README.md](app/README.md) for Flutter setup, Android/iOS release builds, and API notes.
