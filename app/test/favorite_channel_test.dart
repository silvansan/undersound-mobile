import 'package:flutter_test/flutter_test.dart';
import 'package:ablaut_app/models/favorite_channel.dart';

void main() {
  test('old favorite schema without access fields still loads', () {
    final favorite = FavoriteChannel.fromJson({
      'id': '1',
      'name': 'My channel',
      'url': 'https://voice.example.com/listen/evt/en',
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    });

    expect(favorite.listenerPasswordRequired, isFalse);
    expect(favorite.listenerSessionToken, isNull);
    expect(favorite.isPasswordProtected, isFalse);
  });

  test('valid session token respects expiry', () {
    final favorite = FavoriteChannel(
      id: '1',
      name: 'Locked',
      url: 'https://voice.example.com/listen/evt/en',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      listenerPasswordRequired: true,
      listenerSessionToken: 'token',
      sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(favorite.validListenerSessionToken, 'token');
  });

  test('expired session token is ignored', () {
    final favorite = FavoriteChannel(
      id: '1',
      name: 'Locked',
      url: 'https://voice.example.com/listen/evt/en',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      listenerPasswordRequired: true,
      listenerSessionToken: 'token',
      sessionExpiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    expect(favorite.validListenerSessionToken, isNull);
  });
}
