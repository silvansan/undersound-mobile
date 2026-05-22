class ListenerLink {
  const ListenerLink({
    required this.serverUrl,
    required this.eventSlug,
    required this.originalUrl,
    this.channelSlug,
  });

  final Uri serverUrl;
  final String eventSlug;
  final String? channelSlug;
  final Uri originalUrl;

  bool get isEventDirectory => channelSlug == null || channelSlug!.isEmpty;

  ListenerLink withChannelSlug(String channelSlug) {
    return ListenerLink(
      serverUrl: serverUrl,
      eventSlug: eventSlug,
      channelSlug: channelSlug,
      originalUrl: originalUrl,
    );
  }
}
