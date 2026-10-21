import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guarda e devolve tema, localidade e telefone', () async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);

    await preferences.save(
      themeMode: ThemeMode.dark,
      location: '  São Paulo  ',
      phone: '11999990000',
    );

    final restored = AppPreferences();
    addTearDown(restored.dispose);
    await restored.load();

    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.location, 'São Paulo');
    expect(restored.phone, '11999990000');
  });

  test('sem nada salvo começa no tema claro e sem foto', () async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);

    await preferences.load();

    expect(preferences.themeMode, ThemeMode.light);
    expect(preferences.location, '');
    expect(preferences.phone, '');
    expect(preferences.avatarImage, isNull);
  });

  test('guarda a foto e permite remover', () async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);

    await preferences.save(avatarBytes: utf8.encode('foto'));
    expect(preferences.avatarImage, isNotNull);

    final restored = AppPreferences();
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.avatarBytes, isNotNull);

    await restored.save(removeAvatar: true);
    expect(restored.avatarImage, isNull);

    final again = AppPreferences();
    addTearDown(again.dispose);
    await again.load();
    expect(again.avatarImage, isNull);
  });

  test('foto com base64 inválido é ignorada, sem quebrar a leitura', () async {
    SharedPreferences.setMockInitialValues({
      'modern_diary_avatar': 'não-é-base64',
      'modern_diary_theme_mode': 'dark',
    });

    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    await preferences.load();

    expect(preferences.avatarImage, isNull);
    expect(preferences.themeMode, ThemeMode.dark);
  });
}
