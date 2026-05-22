class EventDirectoryChannel {
  const EventDirectoryChannel({
    required this.name,
    required this.slug,
    this.description,
    this.languageCode,
    this.languageLabel,
    this.listenerTokenMode,
    this.listenerUrl,
    this.webrtcEnabled,
  });

  final String name;
  final String slug;
  final String? description;
  final String? languageCode;
  final String? languageLabel;
  final String? listenerTokenMode;
  final String? listenerUrl;
  final bool? webrtcEnabled;

  factory EventDirectoryChannel.fromJson(Map<String, dynamic> json) {
    return EventDirectoryChannel(
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      languageCode: json['languageCode']?.toString(),
      languageLabel: json['languageLabel']?.toString(),
      listenerTokenMode: json['listenerTokenMode']?.toString(),
      listenerUrl: json['listenerUrl']?.toString(),
      webrtcEnabled: json['webrtcEnabled'] as bool?,
    );
  }
}

class EventDirectoryAccess {
  const EventDirectoryAccess({
    required this.listenerPasswordConfigured,
    required this.listenerPasswordMissing,
    required this.listenerPasswordRequired,
    required this.verifyPasswordEndpoint,
  });

  final bool listenerPasswordConfigured;
  final bool listenerPasswordMissing;
  final bool listenerPasswordRequired;
  final String verifyPasswordEndpoint;

  factory EventDirectoryAccess.fromJson(Map<String, dynamic> json) {
    return EventDirectoryAccess(
      listenerPasswordConfigured: json['listenerPasswordConfigured'] == true,
      listenerPasswordMissing: json['listenerPasswordMissing'] == true,
      listenerPasswordRequired: json['listenerPasswordRequired'] == true,
      verifyPasswordEndpoint:
          json['verifyPasswordEndpoint']?.toString() ?? '/api/listener/verify-password',
    );
  }
}

class EventDirectoryContext {
  const EventDirectoryContext({
    required this.access,
    required this.channels,
    required this.eventSlug,
    required this.eventTitle,
  });

  final EventDirectoryAccess access;
  final List<EventDirectoryChannel> channels;
  final String eventSlug;
  final String eventTitle;

  factory EventDirectoryContext.fromJson(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>? ?? const {};
    final channels = json['channels'] as List<dynamic>? ?? const [];

    return EventDirectoryContext(
      access: EventDirectoryAccess.fromJson(
        json['access'] as Map<String, dynamic>? ?? const {},
      ),
      channels: channels
          .whereType<Map<String, dynamic>>()
          .map(EventDirectoryChannel.fromJson)
          .where((channel) => channel.slug.isNotEmpty && channel.name.isNotEmpty)
          .toList(),
      eventSlug: event['slug']?.toString() ?? '',
      eventTitle: event['title']?.toString() ?? '',
    );
  }
}
