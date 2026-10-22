import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../core/strings/app_strings.dart';
import '../../agenda/data/holidays_repository.dart';
import '../data/countries_repository.dart';
import '../domain/country_models.dart';
import 'country_picker.dart';

/// O que o usuário mudou no formulário; o chamador aplica e confirma.
class SettingsDraft {
  const SettingsDraft({
    required this.themeMode,
    required this.location,
    required this.phone,
    this.nationalityIso2,
    this.nationalityName,
    this.avatarBytes,
    this.removeAvatar = false,
  });

  final ThemeMode themeMode;
  final String location;
  final String phone;
  final String? nationalityIso2;
  final String? nationalityName;
  final Uint8List? avatarBytes;
  final bool removeAvatar;
}

/// Abre as configurações básicas: tema, foto, nacionalidade, localidade e
/// telefone.
Future<SettingsDraft?> showSettingsDialog(
  BuildContext context, {
  required AppPreferences preferences,
  required CountriesDataSource countries,
  required HolidaysDataSource holidays,
  required ToatController toat,
  VoidCallback? onHolidaysSynced,
}) {
  return showAppDialog<SettingsDraft>(
    context,
    title: AppStrings.settingsTitle,
    closeLabel: AppStrings.close,
    maxWidth: 520,
    child: _SettingsBody(
      preferences: preferences,
      countries: countries,
      holidays: holidays,
      toat: toat,
      onHolidaysSynced: onHolidaysSynced,
    ),
  );
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody({
    required this.preferences,
    required this.countries,
    required this.holidays,
    required this.toat,
    this.onHolidaysSynced,
  });

  final AppPreferences preferences;
  final CountriesDataSource countries;
  final HolidaysDataSource holidays;
  final ToatController toat;

  /// Avisa a tela por trás do modal para recarregar a agenda com os feriados.
  final VoidCallback? onHolidaysSynced;

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  late final TextEditingController _locationController;
  late final TextEditingController _phoneController;
  late ThemeMode _themeMode;
  String? _nationalityIso2;
  String? _nationalityName;
  Uint8List? _avatarBytes;
  bool _removeAvatar = false;
  String? _avatarError;
  bool _isSyncingHolidays = false;

  @override
  void initState() {
    super.initState();
    final preferences = widget.preferences;
    _themeMode = preferences.themeMode;
    _avatarBytes = preferences.avatarBytes;
    _nationalityIso2 = preferences.nationalityIso2;
    _nationalityName = preferences.nationalityName;
    _locationController = TextEditingController(text: preferences.location);
    _phoneController = TextEditingController(text: preferences.phone);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickNationality() async {
    final selected = await showCountryPicker(
      context,
      dataSource: widget.countries,
      selectedIso2: _nationalityIso2,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _nationalityIso2 = selected.iso2;
      _nationalityName = selected.name;
    });
  }

  void _clearNationality() {
    setState(() {
      _nationalityIso2 = null;
      _nationalityName = null;
    });
  }

  /// Puxa os feriados do país da nacionalidade. Sem nacionalidade, pede que o
  /// usuário escolha uma antes de chamar o back.
  Future<void> _syncHolidays() async {
    if (_isSyncingHolidays) {
      return;
    }

    var iso2 = _nationalityIso2;
    if (iso2 == null || iso2.isEmpty) {
      widget.toat.show(
        AppStrings.holidaySyncChooseNationality,
        variant: ToatVariant.info,
      );
      final selected = await showCountryPicker(
        context,
        dataSource: widget.countries,
        selectedIso2: _nationalityIso2,
      );
      if (selected == null || !mounted) {
        return;
      }
      setState(() {
        _nationalityIso2 = selected.iso2;
        _nationalityName = selected.name;
      });
      iso2 = selected.iso2;
    }

    setState(() => _isSyncingHolidays = true);
    try {
      final result = await widget.holidays.sync(iso2);
      if (!mounted) {
        return;
      }
      widget.toat.show(
        AppStrings.holidaySyncDone(result.total),
        variant: ToatVariant.success,
      );
      widget.onHolidaysSynced?.call();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      widget.toat.show(error.message, variant: ToatVariant.error);
    } finally {
      if (mounted) {
        setState(() => _isSyncingHolidays = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final bytes = result == null || result.files.isEmpty
          ? null
          : result.files.first.bytes;
      if (bytes == null || !mounted) {
        return;
      }
      setState(() {
        if (bytes.length > maxAvatarBytes) {
          _avatarError = AppStrings.settingsAvatarTooLarge;
          return;
        }
        _avatarBytes = bytes;
        _removeAvatar = false;
        _avatarError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _avatarError = AppStrings.settingsAvatarFailed);
      }
    }
  }

  void _removeAvatarPhoto() {
    setState(() {
      _avatarBytes = null;
      _removeAvatar = true;
      _avatarError = null;
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      SettingsDraft(
        themeMode: _themeMode,
        location: _locationController.text,
        phone: _phoneController.text,
        nationalityIso2: _nationalityIso2,
        nationalityName: _nationalityName,
        avatarBytes: _avatarBytes,
        removeAvatar: _removeAvatar,
      ),
    );
  }

  /// Campo de nacionalidade: abre a busca de país e mostra o escolhido.
  Widget _buildNationalityField(TextTheme textTheme, ColorScheme colorScheme) {
    final iso2 = _nationalityIso2;
    final hasNationality = iso2 != null && iso2.isNotEmpty;
    final flag = hasNationality ? countryFlagEmoji(iso2) : '';
    final label = hasNationality
        ? (_nationalityName ?? iso2)
        : AppStrings.settingsNationalityHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppStrings.settingsNationalityLabel, style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: AppSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                borderRadius: AppSpacing.radiusMd,
                elevated: false,
                child: Semantics(
                  button: true,
                  excludeSemantics: true,
                  label: '${AppStrings.settingsNationalityLabel}: $label',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: _pickNationality,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          if (flag.isNotEmpty) ...[
                            Text(
                              flag,
                              style: textTheme.titleMedium,
                              semanticsLabel: '',
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ] else ...[
                            Icon(
                              Icons.public_rounded,
                              size: AppSpacing.iconSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: hasNationality
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            size: AppSpacing.iconSize,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hasNationality)
              IconButton(
                tooltip: AppStrings.settingsNationalityClear,
                onPressed: _clearNationality,
                icon: Icon(
                  Icons.close_rounded,
                  size: AppSpacing.iconSize,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Botão que puxa os feriados do país; depende da nacionalidade escolhida.
  Widget _buildHolidaySync(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.holidaySyncHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: AppStrings.holidaySyncButton,
          icon: Icons.celebration_outlined,
          variant: AppButtonVariant.secondary,
          isLoading: _isSyncingHolidays,
          onPressed: _isSyncingHolidays ? null : _syncHolidays,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppChoiceChips<ThemeMode>(
          label: AppStrings.settingsThemeLabel,
          selected: _themeMode,
          options: const [
            AppChoiceOption(
              value: ThemeMode.light,
              label: AppStrings.settingsThemeLight,
            ),
            AppChoiceOption(
              value: ThemeMode.dark,
              label: AppStrings.settingsThemeDark,
            ),
            AppChoiceOption(
              value: ThemeMode.system,
              label: AppStrings.settingsThemeSystem,
            ),
          ],
          onChanged: (mode) => setState(() => _themeMode = mode),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.settingsProfileSection, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _AvatarPreview(bytes: _removeAvatar ? null : _avatarBytes),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.settingsAvatarLabel,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppButton(
                        label: AppStrings.settingsAvatarChoose,
                        icon: Icons.photo_camera_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: _pickAvatar,
                      ),
                      if (_avatarBytes != null && !_removeAvatar)
                        AppButton(
                          label: AppStrings.settingsAvatarRemove,
                          icon: Icons.delete_outline_rounded,
                          variant: AppButtonVariant.ghost,
                          onPressed: _removeAvatarPhoto,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_avatarError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _avatarError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        _buildNationalityField(textTheme, colorScheme),
        const SizedBox(height: AppSpacing.sm),
        _buildHolidaySync(textTheme, colorScheme),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _locationController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: AppStrings.settingsLocationLabel,
            hintText: AppStrings.settingsLocationHint,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: AppStrings.settingsPhoneLabel,
            hintText: AppStrings.settingsPhoneHint,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const InlineMessage(
          message: AppStrings.settingsLocalNote,
          variant: InlineMessageVariant.info,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.cancel),
            ),
            AppButton(
              label: AppStrings.settingsSave,
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}

/// Prévia circular da foto; sem foto, mostra o ícone de perfil.
class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = bytes;

    return Semantics(
      image: true,
      label: AppStrings.settingsAvatarLabel,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: 28,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: image == null ? null : MemoryImage(image),
        child: image == null
            ? Icon(
                Icons.person_outline_rounded,
                color: colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}
