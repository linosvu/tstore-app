import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccessToken = 'tristore_access_token';

class TokenStorage {
  TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> writeAccessToken(String token) =>
      _storage.write(key: _kAccessToken, value: token);

  static Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  static Future<void> clear() => _storage.delete(key: _kAccessToken);
}
