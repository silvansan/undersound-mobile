import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/listener_link.dart';
import '../models/public_channel.dart';
import 'android_power_service.dart';
import 'hls_service.dart';
import 'livekit_playback_controller.dart';
import 'livekit_service.dart';
import 'stream_connection_service.dart';
import 'ablaut_api_client.dart';

enum AblautPlaybackStatus {
  idle,
  connecting,
  buffering,
  playing,
  paused,
  reconnecting,
  waiting,
  error,
}

extension AblautPlaybackStatusLabel on AblautPlaybackStatus {
  String get label {
    return switch (this) {
      AblautPlaybackStatus.idle => 'Ready',
      AblautPlaybackStatus.connecting => 'Connecting',
      AblautPlaybackStatus.buffering => 'Buffering',
      AblautPlaybackStatus.playing => 'Playing',
      AblautPlaybackStatus.paused => 'Paused',
      AblautPlaybackStatus.reconnecting => 'Reconnecting',
      AblautPlaybackStatus.waiting => 'Waiting for speaker',
      AblautPlaybackStatus.error => 'Audio stream not available',
    };
  }
}

class AblautPlaybackSnapshot {
  const AblautPlaybackSnapshot({
    required this.status,
    required this.playing,
    this.message,
  });

  final AblautPlaybackStatus status;
  final bool playing;
  final String? message;

  String get displayText => message ?? status.label;
}

class AblautStreamRequest {
  const AblautStreamRequest({
    required this.link,
    required this.channelContext,
  });

  final ListenerLink link;
  final PublicChannelContext channelContext;
}

class AblautAudioService {
  AblautAudioService._();

  static final AblautAudioService instance = AblautAudioService._();

  AblautAudioHandler? _handler;
  final LiveKitPlaybackController webRtcController =
      LiveKitPlaybackController();

  AblautAudioHandler get handler {
    final handler = _handler;
    if (handler == null) {
      throw StateError('ablaut audio service has not been initialized.');
    }
    return handler;
  }

  Future<void> initialize() async {
    if (_handler != null) {
      return;
    }

    _handler = await AudioService.init<AblautAudioHandler>(
      builder: () => AblautAudioHandler(
        webRtcController: webRtcController,
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ablaut.mobile.playback',
        androidNotificationChannelName: 'ablaut playback',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }
}

enum _NotificationTransport {
  hls,
  webRtc,
}

class AblautAudioHandler extends BaseAudioHandler {
  AblautAudioHandler({
    required LiveKitPlaybackController webRtcController,
    AblautApiClient apiClient = const AblautApiClient(),
    AndroidPowerService powerService = const AndroidPowerService(),
  })  : _webRtcController = webRtcController,
        _hlsService = HlsService(apiClient),
        _powerService = powerService {
    _configure();
  }

  static const _retryBaseDelay = Duration(seconds: 2);
  static const _maxRetryDelay = Duration(seconds: 30);
  static const _bufferingReconnectDelay = Duration(seconds: 20);
  static const _customActionMute = 'webrtc_mute';
  static const _customActionUnmute = 'webrtc_unmute';

  final LiveKitPlaybackController _webRtcController;
  final HlsService _hlsService;
  final AndroidPowerService _powerService;
  final AudioPlayer _player = AudioPlayer();
  final _snapshotController =
      StreamController<AblautPlaybackSnapshot>.broadcast();

  AblautStreamRequest? _request;
  Uri? _currentUrl;
  bool _wantsPlayback = false;
  bool _reconnecting = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;
  Timer? _bufferingTimer;
  StreamSubscription<PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<LiveKitPlaybackSnapshot>? _webRtcSnapshotSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;
  _NotificationTransport? _notificationTransport;

  Stream<AblautPlaybackSnapshot> get snapshots =>
      _snapshotController.stream;

  AblautPlaybackSnapshot get snapshot => AblautPlaybackSnapshot(
        status: _status,
        playing: _player.playing,
        message: _message,
      );

  AblautPlaybackStatus _status = AblautPlaybackStatus.idle;
  String? _message;

  Future<void> playChannel(AblautStreamRequest request) async {
    _request = request;
    _notificationTransport = _NotificationTransport.hls;
    _wantsPlayback = true;
    _retryAttempt = 0;
    developer.log(
      'Starting ablaut playback for channel ${request.channelContext.channel.id}.',
      name: 'ablaut.Audio',
    );
    await _powerService.requestPostNotificationsPermission();
    await _setKeepAlive(true);
    await _loadAndPlay(refreshUrl: true);
  }

  Future<HlsStatus> refreshHlsStatus(AblautStreamRequest request) {
    return _loadHlsStatus(request);
  }

  @override
  Future<void> play() async {
    if (_notificationTransport == _NotificationTransport.webRtc &&
        _webRtcController.hasActiveSession) {
      await _powerService.requestPostNotificationsPermission();
      await _webRtcController.reconnectActiveSession();
      return;
    }

    final request = _request;
    if (request == null) {
      return;
    }
    _wantsPlayback = true;
    await _setKeepAlive(true);
    if (_currentUrl == null) {
      await _loadAndPlay(refreshUrl: true);
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (_notificationTransport == _NotificationTransport.webRtc) {
      await _webRtcController.disconnect(keepSession: true);
      _publishWebRtcNotification(_webRtcController.snapshot);
      return;
    }

    _wantsPlayback = false;
    _retryTimer?.cancel();
    _bufferingTimer?.cancel();
    await _player.pause();
    await _setKeepAlive(false);
    _setStatus(AblautPlaybackStatus.paused);
  }

  @override
  Future<void> stop() async {
    if (_notificationTransport == _NotificationTransport.webRtc) {
      await _webRtcController.disconnect();
      _notificationTransport = null;
      _publishIdleNotificationState();
      return super.stop();
    }

    _wantsPlayback = false;
    _retryTimer?.cancel();
    _bufferingTimer?.cancel();
    await _player.stop();
    await _setKeepAlive(false);
    _setStatus(AblautPlaybackStatus.idle);
    return super.stop();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_notificationTransport == _NotificationTransport.webRtc) {
      await _webRtcController.toggleMuted();
      return;
    }
    return super.skipToPrevious();
  }

  @override
  Future<void> skipToNext() async {
    if (_notificationTransport == _NotificationTransport.webRtc) {
      await _webRtcController.disconnect();
      _notificationTransport = null;
      _publishIdleNotificationState();
      return;
    }
    return super.skipToNext();
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    _bufferingTimer?.cancel();
    await _playbackEventSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _webRtcSnapshotSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
    await _player.dispose();
    await _snapshotController.close();
  }

  Future<void> _configure() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _becomingNoisySubscription = session.becomingNoisyEventStream.listen(
      (_) {
        unawaited(_handleAudioBecomingNoisy());
      },
    );

    _playbackEventSubscription = _player.playbackEventStream.listen(
      (event) {
        playbackState.add(_transformEvent(event));
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Playback event error.',
          name: 'ablaut.Audio',
          error: error,
          stackTrace: stackTrace,
        );
        _scheduleReconnect('Audio connection changed.');
      },
    );

    _playerStateSubscription = _player.playerStateStream.listen(
      _handlePlayerState,
    );

    _webRtcSnapshotSubscription = _webRtcController.snapshots.listen(
      _publishWebRtcNotification,
    );
  }

  Future<void> _handleAudioBecomingNoisy() async {
    developer.log(
      'Audio output disconnected; pausing playback.',
      name: 'ablaut.Audio',
    );

    if (_notificationTransport == _NotificationTransport.webRtc &&
        _webRtcController.hasActiveSession) {
      await _webRtcController.pauseForRouteChange();
      _publishWebRtcNotification(_webRtcController.snapshot);
      return;
    }

    if (_notificationTransport == _NotificationTransport.hls ||
        _player.playing) {
      await pause();
      _setStatus(
        AblautPlaybackStatus.paused,
        'Playback paused because audio output disconnected.',
      );
    }
  }

  Future<void> _loadAndPlay({required bool refreshUrl}) async {
    final request = _request;
    if (request == null) {
      return;
    }

    try {
      _setStatus(
        _reconnecting
            ? AblautPlaybackStatus.reconnecting
            : AblautPlaybackStatus.connecting,
      );
      final url = refreshUrl || _currentUrl == null
          ? await _resolveStreamUrl(request)
          : _currentUrl;

      if (url == null) {
        _setStatus(
          AblautPlaybackStatus.waiting,
          'HLS is not running yet. Ask the speaker to start publishing.',
        );
        _scheduleReconnect('HLS status is not active.');
        return;
      }

      _currentUrl = url;
      developer.log(
        'Resolved HLS URL: $url',
        name: 'ablaut.Audio',
      );
      mediaItem.add(
        MediaItem(
          id: url.toString(),
          title: 'ablaut',
          album: request.channelContext.event.name,
          artist:
              '${request.channelContext.event.name} - ${request.channelContext.channel.name}',
          extras: {'url': url.toString()},
        ),
      );

      await _player.setAudioSource(
        AudioSource.uri(
          url,
          tag: MediaItem(
            id: url.toString(),
            title: 'ablaut',
            album: request.channelContext.event.name,
            artist:
                '${request.channelContext.event.name} - ${request.channelContext.channel.name}',
          ),
        ),
      );
      await _player.play();
      developer.log(
        'Playback started: duration=${_player.duration}, '
        'position=${_player.position}, buffered=${_player.bufferedPosition}, '
        'processing=${_player.processingState}.',
        name: 'ablaut.Audio',
      );
      _retryAttempt = 0;
      _reconnecting = false;
      _setStatus(AblautPlaybackStatus.playing);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to start HLS stream.',
        name: 'ablaut.Audio',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleReconnect('Audio stream not available. Reconnecting...');
    }
  }

  Future<Uri?> _resolveStreamUrl(AblautStreamRequest request) async {
    final url = await _hlsService.resolvePlayableUrl(
      serverUrl: request.link.serverUrl,
      channel: request.channelContext.channel,
    );
    if (url == null) {
      developer.log(
        'Fallback audio URL could not be resolved.',
        name: 'ablaut.Audio',
      );
    }
    return url;
  }

  Future<HlsStatus> _loadHlsStatus(AblautStreamRequest request) {
    return _hlsService.loadRawStatus(
      serverUrl: request.link.serverUrl,
      channel: request.channelContext.channel,
    );
  }

  void _handlePlayerState(PlayerState state) {
    developer.log(
      'Player state: playing=${state.playing}, processing=${state.processingState}, '
      'position=${_player.position}, buffered=${_player.bufferedPosition}, '
      'duration=${_player.duration}.',
      name: 'ablaut.Audio',
    );

    if (state.processingState == ProcessingState.buffering ||
        state.processingState == ProcessingState.loading) {
      if (_wantsPlayback) {
        _setStatus(AblautPlaybackStatus.buffering);
        _startBufferingWatchdog();
      }
      return;
    }

    _bufferingTimer?.cancel();

    if (state.playing && state.processingState == ProcessingState.ready) {
      _setStatus(AblautPlaybackStatus.playing);
      return;
    }

    if (!state.playing && !_wantsPlayback) {
      _setStatus(AblautPlaybackStatus.paused);
      return;
    }

    if (_wantsPlayback &&
        (state.processingState == ProcessingState.idle ||
            state.processingState == ProcessingState.completed)) {
      developer.log(
        'Playback reached ${state.processingState}; current URL=$_currentUrl.',
        name: 'ablaut.Audio',
      );
      _scheduleReconnect('Playback stopped unexpectedly.');
    }
  }

  void _startBufferingWatchdog() {
    if (_bufferingTimer?.isActive ?? false) {
      return;
    }
    _bufferingTimer = Timer(_bufferingReconnectDelay, () {
      if (!_wantsPlayback) {
        return;
      }
      _scheduleReconnect('Stream is still buffering.');
    });
  }

  void _scheduleReconnect(String reason) {
    if (!_wantsPlayback) {
      return;
    }

    _retryTimer?.cancel();
    _reconnecting = true;
    _setStatus(AblautPlaybackStatus.reconnecting, 'Reconnecting...');
    final delaySeconds =
        (_retryBaseDelay.inSeconds * (1 << _retryAttempt)).clamp(
      _retryBaseDelay.inSeconds,
      _maxRetryDelay.inSeconds,
    );
    _retryAttempt = (_retryAttempt + 1).clamp(0, 8);

    developer.log(
      '$reason Retrying in ${delaySeconds}s.',
      name: 'ablaut.Audio',
    );
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      _loadAndPlay(refreshUrl: true);
    });
  }

  Future<void> _setKeepAlive(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (error, stackTrace) {
      developer.log(
        'Wakelock update failed.',
        name: 'ablaut.Audio',
        error: error,
        stackTrace: stackTrace,
      );
    }
    await _powerService.setWifiLockEnabled(enabled);
  }

  void _setStatus(AblautPlaybackStatus status, [String? message]) {
    _status = status;
    _message = message;
    _snapshotController.add(snapshot);
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case _customActionMute:
        await _webRtcController.setMuted(true);
        return null;
      case _customActionUnmute:
        await _webRtcController.setMuted(false);
        return null;
    }
    return super.customAction(name, extras);
  }

  void _publishWebRtcNotification(LiveKitPlaybackSnapshot snapshot) {
    final context = _webRtcController.activeChannelContext;
    final link = _webRtcController.activeLink;
    if (context == null || link == null) {
      if (_notificationTransport == _NotificationTransport.webRtc) {
        _publishIdleNotificationState();
      }
      return;
    }

    if (snapshot.phase != StreamConnectionPhase.idle ||
        _notificationTransport == _NotificationTransport.webRtc) {
      _notificationTransport = _NotificationTransport.webRtc;
    } else {
      return;
    }

    unawaited(_powerService.requestPostNotificationsPermission());

    mediaItem.add(
      MediaItem(
        id: link.originalUrl.toString(),
        title: 'ablaut',
        album: context.event.name,
        artist: '${context.event.name} - ${context.channel.name}',
        extras: {
          'transport': 'webrtc',
          'server': link.serverUrl.toString(),
        },
      ),
    );

    playbackState.add(_webRtcPlaybackState(snapshot));
  }

  PlaybackState _webRtcPlaybackState(LiveKitPlaybackSnapshot snapshot) {
    final controls = <MediaControl>[
      if (snapshot.connected ||
          snapshot.phase == StreamConnectionPhase.connecting ||
          snapshot.phase == StreamConnectionPhase.reconnecting)
        MediaControl.pause
      else
        MediaControl.play,
      _nativeMuteControl(snapshot.muted),
      const MediaControl(
        androidIcon: 'drawable/audio_service_stop',
        label: 'Stop',
        action: MediaAction.skipToNext,
      ),
    ];

    return PlaybackState(
      controls: controls,
      androidCompactActionIndices: const [0, 1],
      processingState: switch (snapshot.phase) {
        StreamConnectionPhase.connecting => AudioProcessingState.loading,
        StreamConnectionPhase.reconnecting => AudioProcessingState.buffering,
        StreamConnectionPhase.connected => AudioProcessingState.ready,
        StreamConnectionPhase.failed => AudioProcessingState.error,
        StreamConnectionPhase.idle => AudioProcessingState.ready,
      },
      playing: snapshot.connected ||
          snapshot.phase == StreamConnectionPhase.connecting ||
          snapshot.phase == StreamConnectionPhase.reconnecting,
    );
  }

  MediaControl _nativeMuteControl(bool muted) {
    return MediaControl(
      androidIcon: muted
          ? 'drawable/ic_notification_volume_up'
          : 'drawable/ic_notification_volume_off',
      label: muted ? 'Unmute' : 'Mute',
      action: MediaAction.skipToPrevious,
    );
  }

  void _publishIdleNotificationState() {
    playbackState.add(
      PlaybackState(
        controls: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }
}
