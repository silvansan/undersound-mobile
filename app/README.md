# undersound_mobile

Flutter companion app for UnderSound listeners.

On the **Listen** screen, **WebRTC (LiveKit)** is the default for the lowest latency while the LiveKit session is active. Toggle **HLS** for buffered HTTP playback via **audio_service / just_audio**—that route is tuned for reliable **Android background listening** whenever HLS egress is available from the speaker side.

LiveKit joins use **`GET /api/livekit/token`**. Deployments may expose the signaling URL as **`url`**, **`livekitUrl`**, or **`websocketUrl`** in the JSON; this client accepts whichever the server sends.

## Getting Started

This project uses standard Flutter tooling. For Flutter setup, see  
[installation](https://docs.flutter.dev/get-started/install).
