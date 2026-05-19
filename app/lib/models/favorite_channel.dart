class FavoriteChannel {
  const FavoriteChannel({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
    required this.updatedAt,
    this.listenerPasswordRequired = false,
    this.listenerSessionToken,
    this.sessionExpiresAt,
  });

  final String id;
  final String name;
  final String url;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool listenerPasswordRequired;
  final String? listenerSessionToken;
  final DateTime? sessionExpiresAt;

  bool get isPasswordProtected => listenerPasswordRequired;

  String? get validListenerSessionToken {
    final token = listenerSessionToken;
    if (token == null || token.isEmpty) {
      return null;
    }
    final expiresAt = sessionExpiresAt;
    if (expiresAt == null) {
      return token;
    }
    if (DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)))) {
      return null;
    }
    return token;
  }

  FavoriteChannel copyWith({
    String? id,
    String? name,
    String? url,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? listenerPasswordRequired,
    String? listenerSessionToken,
    DateTime? sessionExpiresAt,
    bool clearSession = false,
  }) {
    return FavoriteChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      listenerPasswordRequired:
          listenerPasswordRequired ?? this.listenerPasswordRequired,
      listenerSessionToken: clearSession
          ? null
          : listenerSessionToken ?? this.listenerSessionToken,
      sessionExpiresAt:
          clearSession ? null : sessionExpiresAt ?? this.sessionExpiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (listenerPasswordRequired) 'listenerPasswordRequired': true,
      if (listenerSessionToken != null && listenerSessionToken!.isNotEmpty)
        'listenerSessionToken': listenerSessionToken,
      if (sessionExpiresAt != null)
        'sessionExpiresAt': sessionExpiresAt!.toIso8601String(),
    };
  }

  factory FavoriteChannel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return FavoriteChannel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'ablaut channel',
      url: json['url']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
      listenerPasswordRequired: json['listenerPasswordRequired'] == true,
      listenerSessionToken: json['listenerSessionToken']?.toString(),
      sessionExpiresAt: DateTime.tryParse(
        json['sessionExpiresAt']?.toString() ?? '',
      ),
    );
  }
}
