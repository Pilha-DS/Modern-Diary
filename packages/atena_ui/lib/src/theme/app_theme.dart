import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.holiday,
    required this.holidaySoft,
    required this.shadow,
    required this.highlightShadow,
    required this.contrastSurface,
    required this.contrastInk,
  });

  final Color brand;
  final Color brandDeep;
  final Color brandSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;

  /// Laranja exclusivo do status "feriado" no calendário.
  final Color holiday;
  final Color holidaySoft;
  final Color shadow;

  /// Sombra azul usada no destaque do mês atual.
  final Color highlightShadow;

  /// Superfície invertida em relação ao tema, para elementos que precisam
  /// saltar do fundo (o menu orbital): no claro fica escura, no escuro fica
  /// clara. [contrastInk] é o texto/ícone que contrasta com ela.
  final Color contrastSurface;
  final Color contrastInk;

  static AppSemanticColors of(BuildContext context) {
    final colors = Theme.of(context).extension<AppSemanticColors>();
    assert(colors != null, 'AppSemanticColors não foi registrado no tema.');
    return colors!;
  }

  @override
  AppSemanticColors copyWith({
    Color? brand,
    Color? brandDeep,
    Color? brandSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? holiday,
    Color? holidaySoft,
    Color? shadow,
    Color? highlightShadow,
    Color? contrastSurface,
    Color? contrastInk,
  }) {
    return AppSemanticColors(
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      brandSoft: brandSoft ?? this.brandSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      holiday: holiday ?? this.holiday,
      holidaySoft: holidaySoft ?? this.holidaySoft,
      shadow: shadow ?? this.shadow,
      highlightShadow: highlightShadow ?? this.highlightShadow,
      contrastSurface: contrastSurface ?? this.contrastSurface,
      contrastInk: contrastInk ?? this.contrastInk,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      holiday: Color.lerp(holiday, other.holiday, t)!,
      holidaySoft: Color.lerp(holidaySoft, other.holidaySoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      highlightShadow: Color.lerp(highlightShadow, other.highlightShadow, t)!,
      contrastSurface: Color.lerp(contrastSurface, other.contrastSurface, t)!,
      contrastInk: Color.lerp(contrastInk, other.contrastInk, t)!,
    );
  }
}

abstract final class AppTheme {
  /// Tema claro a partir da paleta do projeto. Sem `palette`, usa a de exemplo.
  static ThemeData light({AppPalette palette = AppPalette.example}) {
    return _build(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: palette.brand,
            brightness: Brightness.light,
          ).copyWith(
            primary: palette.blue,
            onPrimary: palette.surface,
            primaryContainer: palette.blueSoft,
            onPrimaryContainer: palette.ink,
            secondary: palette.grayMedium,
            onSecondary: palette.surface,
            secondaryContainer: palette.graySoft,
            onSecondaryContainer: palette.ink,
            tertiary: palette.brand,
            onTertiary: palette.surface,
            tertiaryContainer: palette.brandSoft,
            onTertiaryContainer: palette.ink,
            error: palette.red,
            onError: palette.surface,
            errorContainer: palette.redSoft,
            onErrorContainer: palette.ink,
            surface: palette.surface,
            onSurface: palette.ink,
            surfaceContainerHighest: palette.grayLight,
            onSurfaceVariant: palette.grayMedium,
            outline: palette.graySoft,
            outlineVariant: palette.graySoft,
          ),
      semanticColors: AppSemanticColors(
        brand: palette.brand,
        brandDeep: palette.brandDeep,
        brandSoft: palette.brandSoft,
        success: palette.brand,
        successSoft: palette.brandSoft,
        warning: palette.yellow,
        warningSoft: palette.yellowSoft,
        holiday: palette.holiday,
        holidaySoft: palette.holidaySoft,
        shadow: palette.shadow,
        highlightShadow: palette.highlightShadow,
        contrastSurface: palette.ink,
        contrastInk: palette.surface,
      ),
      scaffoldBackgroundColor: palette.grayLight,
    );
  }

  /// Tema escuro com a mesma paleta e a mesma hierarquia de cores.
  static ThemeData dark({AppPalette palette = AppPalette.example}) {
    return _build(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: palette.darkBrand,
            brightness: Brightness.dark,
          ).copyWith(
            primary: palette.darkBlue,
            onPrimary: palette.darkSurface,
            primaryContainer: palette.darkBlueSoft,
            onPrimaryContainer: palette.darkInk,
            secondary: palette.darkInkMuted,
            onSecondary: palette.darkSurface,
            secondaryContainer: palette.darkSurfaceHigh,
            onSecondaryContainer: palette.darkInk,
            tertiary: palette.darkBrand,
            onTertiary: palette.darkSurface,
            tertiaryContainer: palette.darkBrandSoft,
            onTertiaryContainer: palette.darkInk,
            error: palette.darkRed,
            onError: palette.darkSurface,
            errorContainer: palette.darkRedSoft,
            onErrorContainer: palette.darkInk,
            surface: palette.darkSurface,
            onSurface: palette.darkInk,
            surfaceContainerHighest: palette.darkSurfaceHigh,
            onSurfaceVariant: palette.darkInkMuted,
            outline: palette.darkOutline,
            outlineVariant: palette.darkOutline,
          ),
      semanticColors: AppSemanticColors(
        brand: palette.darkBrand,
        brandDeep: palette.darkBrandDeep,
        brandSoft: palette.darkBrandSoft,
        success: palette.darkBrand,
        successSoft: palette.darkBrandSoft,
        warning: palette.darkYellow,
        warningSoft: palette.darkYellowSoft,
        holiday: palette.darkHoliday,
        holidaySoft: palette.darkHolidaySoft,
        shadow: palette.darkShadow,
        highlightShadow: palette.darkHighlightShadow,
        contrastSurface: palette.darkInk,
        contrastInk: palette.darkSurface,
      ),
      scaffoldBackgroundColor: palette.darkSurface,
    );
  }

  static ThemeData _build({
    required ColorScheme colorScheme,
    required AppSemanticColors semanticColors,
    required Color scaffoldBackgroundColor,
  }) {
    final roundedField = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      extensions: [semanticColors],
      textTheme: _textTheme(colorScheme),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: roundedField,
        enabledBorder: roundedField,
        focusedBorder: roundedField,
        errorBorder: roundedField,
        focusedErrorBorder: roundedField,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        errorStyle: TextStyle(color: colorScheme.error),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme(colorScheme).titleLarge,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSpacing.minTouchTarget),
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.onSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        textStyle: TextStyle(color: colorScheme.surface),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    final base = ThemeData.light().textTheme;
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );
  }
}
