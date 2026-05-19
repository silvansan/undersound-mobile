import 'ablaut_audio_service.dart';

/// Which transport backs playback on the player screen.
enum StreamTransportMode {
  webRtc,
  hls,
}

/// Connection lifecycle surfaced in the unified player UI.
enum StreamConnectionPhase {
  idle,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Maps [AblautPlaybackStatus] from audio_service/HLS playback to the
/// smaller UI surface requested for stream transport.
abstract final class StreamConnectionService {
  const StreamConnectionService._();

  static StreamConnectionPhase phaseForHls(
    AblautPlaybackStatus playback,
  ) {
    return switch (playback) {
      AblautPlaybackStatus.idle => StreamConnectionPhase.idle,
      AblautPlaybackStatus.connecting =>
        StreamConnectionPhase.connecting,
      AblautPlaybackStatus.buffering => StreamConnectionPhase.connecting,
      AblautPlaybackStatus.playing || AblautPlaybackStatus.paused =>
        StreamConnectionPhase.connected,
      AblautPlaybackStatus.reconnecting =>
        StreamConnectionPhase.reconnecting,
      AblautPlaybackStatus.waiting =>
        StreamConnectionPhase.connecting,
      AblautPlaybackStatus.error => StreamConnectionPhase.failed,
    };
  }
}
