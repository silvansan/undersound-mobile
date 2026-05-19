import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores listener passwords locally; never log values from this store.
class ListenerSecureStore {
  const ListenerSecureStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _passwordKey(String url) => 'listener_pwd_${url.trim()}';

  Future<void> savePassword({
    required String url,
    required String password,
  }) async {
    await _storage.write(key: _passwordKey(url), value: password);
  }

  Future<String?> readPassword(String url) {
    return _storage.read(key: _passwordKey(url));
  }

  Future<void> deletePassword(String url) async {
    await _storage.delete(key: _passwordKey(url));
  }
}
