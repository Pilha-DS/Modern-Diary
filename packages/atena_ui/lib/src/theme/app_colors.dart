import 'package:flutter/material.dart';

/// Paleta que a aplicação entrega ao tema.
///
/// O package não tem identidade própria: cada projeto passa a sua paleta em
/// `AppTheme.light(palette: ...)` e `AppTheme.dark(palette: ...)`. Os valores
/// de [AppPalette.example] servem de ponto de partida e para os testes do
/// package.
@immutable
class AppPalette {
  const AppPalette({
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.blue,
    required this.blueSoft,
    required this.grayMedium,
    required this.grayLight,
    required this.graySoft,
    required this.surface,
    required this.ink,
    required this.yellow,
    required this.yellowSoft,
    required this.holiday,
    required this.holidaySoft,
    required this.red,
    required this.redSoft,
    required this.shadow,
    required this.highlightShadow,
    required this.darkSurface,
    required this.darkSurfaceHigh,
    required this.darkInk,
    required this.darkInkMuted,
    required this.darkOutline,
    required this.darkBrand,
    required this.darkBrandDeep,
    required this.darkBrandSoft,
    required this.darkBlue,
    required this.darkBlueSoft,
    required this.darkYellow,
    required this.darkYellowSoft,
    required this.darkHoliday,
    required this.darkHolidaySoft,
    required this.darkRed,
    required this.darkRedSoft,
    required this.darkShadow,
    required this.darkHighlightShadow,
  });

  final Color brand;
  final Color brandDeep;
  final Color brandSoft;
  final Color blue;
  final Color blueSoft;
  final Color grayMedium;
  final Color grayLight;
  final Color graySoft;
  final Color surface;
  final Color ink;
  final Color yellow;
  final Color yellowSoft;
  final Color holiday;
  final Color holidaySoft;
  final Color red;
  final Color redSoft;
  final Color shadow;
  final Color highlightShadow;

  final Color darkSurface;
  final Color darkSurfaceHigh;
  final Color darkInk;
  final Color darkInkMuted;
  final Color darkOutline;
  final Color darkBrand;
  final Color darkBrandDeep;
  final Color darkBrandSoft;
  final Color darkBlue;
  final Color darkBlueSoft;
  final Color darkYellow;
  final Color darkYellowSoft;
  final Color darkHoliday;
  final Color darkHolidaySoft;
  final Color darkRed;
  final Color darkRedSoft;
  final Color darkShadow;
  final Color darkHighlightShadow;

  /// Troca só a identidade da marca, mantendo a estrutura de cores.
  AppPalette copyWith({
    Color? brand,
    Color? brandDeep,
    Color? brandSoft,
    Color? darkBrand,
    Color? darkBrandDeep,
    Color? darkBrandSoft,
  }) {
    return AppPalette(
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      brandSoft: brandSoft ?? this.brandSoft,
      blue: blue,
      blueSoft: blueSoft,
      grayMedium: grayMedium,
      grayLight: grayLight,
      graySoft: graySoft,
      surface: surface,
      ink: ink,
      yellow: yellow,
      yellowSoft: yellowSoft,
      holiday: holiday,
      holidaySoft: holidaySoft,
      red: red,
      redSoft: redSoft,
      shadow: shadow,
      highlightShadow: highlightShadow,
      darkSurface: darkSurface,
      darkSurfaceHigh: darkSurfaceHigh,
      darkInk: darkInk,
      darkInkMuted: darkInkMuted,
      darkOutline: darkOutline,
      darkBrand: darkBrand ?? this.darkBrand,
      darkBrandDeep: darkBrandDeep ?? this.darkBrandDeep,
      darkBrandSoft: darkBrandSoft ?? this.darkBrandSoft,
      darkBlue: darkBlue,
      darkBlueSoft: darkBlueSoft,
      darkYellow: darkYellow,
      darkYellowSoft: darkYellowSoft,
      darkHoliday: darkHoliday,
      darkHolidaySoft: darkHolidaySoft,
      darkRed: darkRed,
      darkRedSoft: darkRedSoft,
      darkShadow: darkShadow,
      darkHighlightShadow: darkHighlightShadow,
    );
  }

  /// Paleta de exemplo. Um projeto novo deve trocar a identidade com
  /// [AppPalette.copyWith] ou montar a própria [AppPalette].
  static const AppPalette example = AppPalette(
    brand: AppColors.brand,
    brandDeep: AppColors.brandDeep,
    brandSoft: AppColors.brandSoft,
    blue: AppColors.blue,
    blueSoft: AppColors.blueSoft,
    grayMedium: AppColors.grayMedium,
    grayLight: AppColors.grayLight,
    graySoft: AppColors.graySoft,
    surface: AppColors.surface,
    ink: AppColors.ink,
    yellow: AppColors.yellow,
    yellowSoft: AppColors.yellowSoft,
    holiday: AppColors.holiday,
    holidaySoft: AppColors.holidaySoft,
    red: AppColors.red,
    redSoft: AppColors.redSoft,
    shadow: AppColors.shadow,
    highlightShadow: AppColors.highlightShadow,
    darkSurface: AppColors.darkSurface,
    darkSurfaceHigh: AppColors.darkSurfaceHigh,
    darkInk: AppColors.darkInk,
    darkInkMuted: AppColors.darkInkMuted,
    darkOutline: AppColors.darkOutline,
    darkBrand: AppColors.darkBrand,
    darkBrandDeep: AppColors.darkBrandDeep,
    darkBrandSoft: AppColors.darkBrandSoft,
    darkBlue: AppColors.darkBlue,
    darkBlueSoft: AppColors.darkBlueSoft,
    darkYellow: AppColors.darkYellow,
    darkYellowSoft: AppColors.darkYellowSoft,
    darkHoliday: AppColors.darkHoliday,
    darkHolidaySoft: AppColors.darkHolidaySoft,
    darkRed: AppColors.darkRed,
    darkRedSoft: AppColors.darkRedSoft,
    darkShadow: AppColors.darkShadow,
    darkHighlightShadow: AppColors.darkHighlightShadow,
  );
}

/// Paleta de exemplo do package. Widgets não usam estas cores diretamente:
/// consomem os tokens expostos em [AppTheme] ou [AppSemanticColors].
abstract final class AppColors {
  static const Color brand = Color(0xFF2E7D5B);
  static const Color brandDeep = Color(0xFF1F5B42);
  static const Color brandSoft = Color(0xFFE6F2EC);

  static const Color blue = Color(0xFF4A7BA7);
  static const Color blueSoft = Color(0xFFE8F0F7);

  static const Color grayMedium = Color(0xFF6B7280);
  static const Color grayLight = Color(0xFFF3F5F4);
  static const Color graySoft = Color(0xFFE9ECEA);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1F2A24);

  static const Color yellow = Color(0xFF94670F);
  static const Color yellowSoft = Color(0xFFFBF3DC);

  /// Laranja do status "feriado" no calendário.
  static const Color holiday = Color(0xFFC2410C);
  static const Color holidaySoft = Color(0xFFFFEDD5);

  static const Color red = Color(0xFFB3261E);
  static const Color redSoft = Color(0xFFFBEAE8);

  static const Color shadow = Color(0x14000000);

  /// Sombra azul do mês atual em destaque.
  static const Color highlightShadow = Color(0x4D4A7BA7);

  // Paleta escura: fundo profundo com o verde da identidade suavizado, para
  // que a mesma hierarquia de cores continue legível.
  static const Color darkSurface = Color(0xFF121A16);
  static const Color darkSurfaceHigh = Color(0xFF1C2721);
  static const Color darkInk = Color(0xFFE7EFEA);
  static const Color darkInkMuted = Color(0xFF9FADA6);
  static const Color darkOutline = Color(0xFF2A3932);
  static const Color darkBrand = Color(0xFF3F9C74);
  static const Color darkBrandDeep = Color(0xFF27684C);
  static const Color darkBrandSoft = Color(0xFF1B2C24);
  static const Color darkBlue = Color(0xFF89B4D6);
  static const Color darkBlueSoft = Color(0xFF22303D);
  static const Color darkYellow = Color(0xFFE5BC63);
  static const Color darkYellowSoft = Color(0xFF3A2E12);
  static const Color darkHoliday = Color(0xFFFDBA74);
  static const Color darkHolidaySoft = Color(0xFF43230C);
  static const Color darkRed = Color(0xFFF2B8B5);
  static const Color darkRedSoft = Color(0xFF3B1F1D);
  static const Color darkShadow = Color(0x66000000);
  static const Color darkHighlightShadow = Color(0x6689B4D6);

  static const Color tagTeal = Color(0xFF2F7F7A);
  static const Color tagPurple = Color(0xFF7A5AA6);
  static const Color tagOrange = Color(0xFFB06A2C);
  static const Color tagPink = Color(0xFFA64A78);
}

/// Cores oferecidas para tags. A tag guarda o hexadecimal escolhido.
abstract final class AppTagColors {
  static const List<Color> choices = [
    AppColors.brand,
    AppColors.blue,
    AppColors.tagTeal,
    AppColors.tagPurple,
    AppColors.tagOrange,
    AppColors.tagPink,
    AppColors.yellow,
    AppColors.grayMedium,
  ];

  static String hexOf(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color parse(String hex, {Color fallback = AppColors.grayMedium}) {
    final value = hex.replaceFirst('#', '');
    if (value.length != 6) {
      return fallback;
    }
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }
}
