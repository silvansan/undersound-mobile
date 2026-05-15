import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_channel.dart';

class FavoritesService {
  const FavoritesService();

  static const _storageKey = 'undersound.favoriteChannels.v1';

  Future<List<FavoriteChannel>> loadFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    final rawItems = preferences.getStringList(_storageKey) ?? const [];
    final favorites = <FavoriteChannel>[];

    for (final rawItem in rawItems) {
      try {
        final decoded = jsonDecode(rawItem);
        if (decoded is Map<String, dynamic>) {
          final favorite = FavoriteChannel.fromJson(decoded);
          if (favorite.id.isNotEmpty && favorite.url.isNotEmpty) {
            favorites.add(favorite);
          }
        }
      } catch (_) {
        // Ignore malformed local entries instead of blocking the list.
      }
    }

    favorites.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return favorites;
  }

  Future<bool> isSavedUrl(String url) async {
    final normalized = _normalizeUrl(url);
    final favorites = await loadFavorites();
    return favorites.any(
      (favorite) => _normalizeUrl(favorite.url) == normalized,
    );
  }

  Future<FavoriteChannel> addFavorite({
    required String name,
    required String url,
  }) async {
    final favorites = await loadFavorites();
    final normalized = _normalizeUrl(url);
    final existing = favorites.where(
      (favorite) => _normalizeUrl(favorite.url) == normalized,
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final now = DateTime.now();
    final favorite = FavoriteChannel(
      id: now.microsecondsSinceEpoch.toString(),
      name: _cleanName(name),
      url: url.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _saveFavorites([favorite, ...favorites]);
    return favorite;
  }

  Future<void> updateFavorite(FavoriteChannel favorite) async {
    final favorites = await loadFavorites();
    final updated = favorite.copyWith(
      name: _cleanName(favorite.name),
      url: favorite.url.trim(),
      updatedAt: DateTime.now(),
    );
    await _saveFavorites([
      for (final item in favorites) item.id == updated.id ? updated : item,
    ]);
  }

  Future<void> deleteFavorite(String id) async {
    final favorites = await loadFavorites();
    await _saveFavorites([
      for (final favorite in favorites)
        if (favorite.id != id) favorite,
    ]);
  }

  Future<void> _saveFavorites(List<FavoriteChannel> favorites) async {
    final preferences = await SharedPreferences.getInstance();
    final rawItems = [
      for (final favorite in favorites) jsonEncode(favorite.toJson()),
    ];
    await preferences.setStringList(_storageKey, rawItems);
  }

  String _cleanName(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'UnderSound channel' : trimmed;
  }

  String _normalizeUrl(String url) => url.trim();
}
