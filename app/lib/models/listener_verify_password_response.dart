class ListenerVerifyPasswordResponse {
  const ListenerVerifyPasswordResponse({
    required this.ok,
    required this.required,
    this.listenerSessionToken,
    this.expiresIn,
  });

  final bool ok;
  final bool required;
  final String? listenerSessionToken;
  final int? expiresIn;

  factory ListenerVerifyPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ListenerVerifyPasswordResponse(
      ok: json['ok'] == true,
      required: json['required'] == true,
      listenerSessionToken: json['listenerSessionToken']?.toString(),
      expiresIn: json['expiresIn'] is int
          ? json['expiresIn'] as int
          : int.tryParse(json['expiresIn']?.toString() ?? ''),
    );
  }
}
