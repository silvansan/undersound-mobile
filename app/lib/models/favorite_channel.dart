class FavoriteChannel {
  const FavoriteChannel({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String url;
  final DateTime createdAt;
  final DateTime updatedAt;

  FavoriteChannel copyWith({
    String? id,
    String? name,
    String? url,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FavoriteChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FavoriteChannel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return FavoriteChannel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'UnderSound channel',
      url: json['url']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }
}
