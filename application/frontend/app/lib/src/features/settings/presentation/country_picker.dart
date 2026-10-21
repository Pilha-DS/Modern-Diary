import 'dart:async';

import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../data/countries_repository.dart';
import '../domain/country_models.dart';

/// Abre a busca de país e devolve o escolhido, ou `null` se o usuário fechar.
Future<Country?> showCountryPicker(
  BuildContext context, {
  required CountriesDataSource dataSource,
  String? selectedIso2,
}) {
  return showAppDialog<Country>(
    context,
    title: AppStrings.countryPickerTitle,
    closeLabel: AppStrings.close,
    maxWidth: 480,
    child: _CountryPickerBody(
      dataSource: dataSource,
      selectedIso2: selectedIso2,
    ),
  );
}

class _CountryPickerBody extends StatefulWidget {
  const _CountryPickerBody({required this.dataSource, this.selectedIso2});

  final CountriesDataSource dataSource;
  final String? selectedIso2;

  @override
  State<_CountryPickerBody> createState() => _CountryPickerBodyState();
}

class _CountryPickerBodyState extends State<_CountryPickerBody> {
  static const Duration _searchDebounce = Duration(milliseconds: 350);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Country> _countries = const [];
  int _page = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  ApiException? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasMore => _page < _totalPages;

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, _loadFirstPage);
  }

  Future<void> _loadFirstPage() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await widget.dataSource.fetchPage(
        page: 1,
        query: _searchController.text,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _countries = page.countries;
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } on ApiException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _error = error;
          _countries = const [];
          _page = 0;
          _totalPages = 0;
        });
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }
    final requestId = _requestId;
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });
    try {
      final page = await widget.dataSource.fetchPage(
        page: _page + 1,
        query: _searchController.text,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _countries = [..._countries, ...page.countries];
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } on ApiException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: AppStrings.countrySearchLabel,
            hintText: AppStrings.countrySearchHint,
            prefixIcon: Icon(Icons.search_rounded, size: AppSpacing.iconSize),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildResults(),
      ],
    );
  }

  Widget _buildResults() {
    if (_isLoading && _countries.isEmpty) {
      return const StatusView.loading(title: AppStrings.countriesLoading);
    }
    if (_error != null && _countries.isEmpty) {
      return StatusView.error(
        title: AppStrings.countriesErrorTitle,
        message: _error!.message,
        actionLabel: AppStrings.retry,
        onAction: _loadFirstPage,
      );
    }
    if (_countries.isEmpty) {
      return const StatusView.empty(
        icon: Icons.public_off_rounded,
        title: AppStrings.countriesEmptyTitle,
        message: AppStrings.countriesEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InlineMessage(
              message: _error!.message,
              variant: InlineMessageVariant.error,
            ),
          ),
        for (final country in _countries)
          _CountryTile(
            country: country,
            isSelected: country.iso2 == widget.selectedIso2,
            onSelected: () => Navigator.of(context).pop(country),
          ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.countriesLoadMore,
              variant: AppButtonVariant.secondary,
              isLoading: _isLoadingMore,
              onPressed: _loadMore,
            ),
          ),
      ],
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.isSelected,
    required this.onSelected,
  });

  final Country country;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      label: '${country.name}, ${country.subtitle}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (country.flagEmoji.isNotEmpty) ...[
                Text(
                  country.flagEmoji,
                  style: textTheme.titleMedium,
                  semanticsLabel: '',
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      country.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                    Text(
                      country.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: AppSpacing.iconSize,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
