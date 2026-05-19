# ablaut mobile app

Flutter listener client for ablaut / UnderSound-Studio deployments.

## Playback

On the player screen, **WebRTC (LiveKit)** is the default for the lowest latency while a LiveKit session is active. Switch to **HLS** for buffered HTTP playback via **audio_service** and **just_audio** when the server exposes HLS egress.

LiveKit credentials come from **`POST /api/livekit/listener-token`**. The response may use `url`, `livekitUrl`, or `websocketUrl` for the signaling endpoint; this client accepts whichever field the server returns.

## Listener access

Public metadata is loaded with:

`GET /api/public/listen/:eventSlug/:channelSlug`

The response includes an `access` block. When `listenerPasswordRequired` is true, the app calls:

`POST /api/listener/verify-password`

and sends the returned `listenerSessionToken` to the listener-token endpoint (body field and/or `X-Ablaut-Listener-Session` header).

Legacy listener URL shapes remain supported (`/listen/...`, `/listener/...`, `/e/.../listen`, `undersound://`).

## Getting started

Install [Flutter](https://docs.flutter.dev/get-started/install), then from this directory:

```bash
flutter pub get
flutter analyze
flutter test
```

Run on a connected device:

```bash
flutter run
```

## Release builds

Place signing config in `android/key.properties` (not committed). Then:

```bash
flutter build apk --release
flutter build appbundle --release
```

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

The Android **applicationId** stays `com.undersound.mobile` so existing installs can upgrade in place. The visible app name is **ablaut**.

## Launcher icons

Regenerate Android/iOS launcher assets after changing logo files:

```bash
dart run flutter_launcher_icons
```

Source assets:

- `assets/ablaut-launcher-icon.png` — full icon with brand background
- `assets/ablaut-icon-foreground.png` — centered mark for adaptive foreground
- `assets/ablaut-logo.png` — in-app logo

## iOS launch screen

Replace launch images under `ios/Runner/Assets.xcassets/LaunchImage.imageset/` or customize the launch storyboard in Xcode. See `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`.
