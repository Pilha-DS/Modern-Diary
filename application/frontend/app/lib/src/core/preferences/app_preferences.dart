import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Limite da foto de perfil guardada neste dispositivo.
const int maxAvatarBytes = 512 * 1024;

/// Ajustes pessoais do usuário: tema, localidade, nacionalidade, telefone e
/// foto.
///
/// São preferências locais, deste dispositivo; não vão para a API. A leitura
/// nunca lança: armazenamento indisponível ou valor ilegível cai no padrão.
class AppPreferences extends ChangeNotifier {
  static const String _themeKey = 'modern_diary_theme_mode';
  static const String _locationKey = 'modern_diary_location';
  static const String _phoneKey = 'modern_diary_phone';
  static const String _nationalityIso2Key = 'modern_diary_nationality_iso2';
  static const String _nationalityNameKey = 'modern_diary_nationality_name';
  static const String _avatarKey = 'modern_diary_avatar';

  ThemeMode _themeMode = ThemeMode.light;
  String _location = '';
  String _phone = '';
  String? _nationalityIso2;
  String? _nationalityName;
  Uint8List? _avatarBytes;

  ThemeMode get themeMode => _themeMode;
  String get location => _location;
  String get phone => _phone;

  /// País escolhido como nacionalidade; `null` quando não informado.
  String? get nationalityIso2 => _nationalityIso2;
  String? get nationalityName => _nationalityName;

  /// Foto enviada pelo usuário; `null` deixa o avatar com as iniciais.
  ImageProvider? get avatarImage {
    final bytes = _avatarBytes;
    return bytes == null ? null : MemoryImage(bytes);
  }

  /// Bytes da foto, para a prévia no formulário de configurações.
  Uint8List? get avatarBytes => _avatarBytes;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _themeMode = _themeModeFromName(preferences.getString(_themeKey));
      _location = preferences.getString(_locationKey) ?? '';
      _phone = preferences.getString(_phoneKey) ?? '';
      _nationalityIso2 = preferences.getString(_nationalityIso2Key);
      _nationalityName = preferences.getString(_nationalityNameKey);
      _avatarBytes = _decodeAvatar(preferences.getString(_avatarKey));
    } catch (_) {
      // Sem armazenamento valem os padrões em memória.
    }
    notifyListeners();
  }

  /// Aplica e persiste. [removeAvatar] apaga a foto atual e
  /// [clearNationality] limpa o país escolhido.
  Future<void> save({
    ThemeMode? themeMode,
    String? location,
    String? phone,
    String? nationalityIso2,
    String? nationalityName,
    bool clearNationality = false,
    Uint8List? avatarBytes,
    bool removeAvatar = false,
  }) async {
    _themeMode = themeMode ?? _themeMode;
    _location = location?.trim() ?? _location;
    _phone = phone?.trim() ?? _phone;
    if (clearNationality) {
      _nationalityIso2 = null;
      _nationalityName = null;
    } else if (nationalityIso2 != null) {
      _nationalityIso2 = nationalityIso2;
      _nationalityName = nationalityName ?? nationalityIso2;
    }
    if (removeAvatar) {
      _avatarBytes = null;
    } else if (avatarBytes != null) {
      _avatarBytes = avatarBytes;
    }
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_themeKey, _themeMode.name);
      await preferences.setString(_locationKey, _location);
      await preferences.setString(_phoneKey, _phone);
      final iso2 = _nationalityIso2;
      final name = _nationalityName;
      if (iso2 == null || name == null) {
        await preferences.remove(_nationalityIso2Key);
        await preferences.remove(_nationalityNameKey);
      } else {
        await preferences.setString(_nationalityIso2Key, iso2);
        await preferences.setString(_nationalityNameKey, name);
      }
      final avatar = _avatarBytes;
      if (avatar == null) {
        await preferences.remove(_avatarKey);
      } else {
        await preferences.setString(_avatarKey, base64Encode(avatar));
      }
    } catch (_) {
      // Sem armazenamento o ajuste vale só enquanto a tela estiver aberta.
    }
  }

  static ThemeMode _themeModeFromName(String? name) {
    return switch (name) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  static Uint8List? _decodeAvatar(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}
