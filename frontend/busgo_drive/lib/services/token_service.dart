import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  static const _kAccess  = 'busgo_drive_access';
  static const _kRefresh = 'busgo_drive_refresh';

  final _store = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveTokens(String access, String refresh) => Future.wait([
    _store.write(key: _kAccess,  value: access),
    _store.write(key: _kRefresh, value: refresh),
  ]);

  Future<String?> getAccessToken()  => _store.read(key: _kAccess);
  Future<String?> getRefreshToken() => _store.read(key: _kRefresh);
  Future<bool>    hasToken() async  => (await getAccessToken()) != null;

  Future<void> clearTokens() => Future.wait([
    _store.delete(key: _kAccess),
    _store.delete(key: _kRefresh),
  ]);
}
