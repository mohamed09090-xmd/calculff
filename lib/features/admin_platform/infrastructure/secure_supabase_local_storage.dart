import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SecureStorageBackend {
  Future<void> write({required String key, required String value});

  Future<String?> read({required String key});

  Future<void> delete({required String key});
}

class FlutterSecureStorageBackend implements SecureStorageBackend {
  const FlutterSecureStorageBackend({
    this.storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(migrateWithBackup: true),
    ),
  });

  final FlutterSecureStorage storage;

  @override
  Future<void> write({required String key, required String value}) {
    return storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return storage.delete(key: key);
  }
}

class SecureSupabaseLocalStorage extends LocalStorage {
  SecureSupabaseLocalStorage({
    SecureStorageBackend? storage,
    this.persistSessionKey = defaultPersistSessionKey,
  }) : _storage = storage ?? const FlutterSecureStorageBackend();

  static const defaultPersistSessionKey = 'supabase.auth.session.v1';

  final SecureStorageBackend _storage;
  final String persistSessionKey;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<bool> hasAccessToken() async {
    return (await accessToken()) != null;
  }

  @override
  Future<String?> accessToken() {
    _ensureInitialized();
    return _storage.read(key: persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() {
    _ensureInitialized();
    return _storage.delete(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    _ensureInitialized();
    if (_containsPasswordField(persistSessionString)) {
      throw const FormatException(
        'Supabase session storage must not contain a password field.',
      );
    }
    return _storage.write(
      key: persistSessionKey,
      value: persistSessionString,
    );
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Secure Supabase local storage is not initialized.');
    }
  }

  bool _containsPasswordField(String value) {
    try {
      return _containsPassword(jsonDecode(value));
    } on FormatException {
      return RegExp(
        r'"password"\s(:',
        caseSensitive: false,
      ).hasMatch(value);
    }
  }

  bool _containsPassword(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key.toString().toLowerCase() == 'password' ||
            _containsPassword(entry.value)) {
          return true;
        }
      }
    } else if (value is Iterable) {
      return value.any(_containsPassword);
    }
    return false;
  }
}
