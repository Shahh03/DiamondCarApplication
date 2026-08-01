import 'package:flutter/material.dart';

import '../../api/renter_api.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _background = Color(0xFFF5F7FB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class CurrencySelectorPage extends StatefulWidget {
  final String id;

  const CurrencySelectorPage({super.key, required this.id});

  @override
  State<CurrencySelectorPage> createState() =>
      _CurrencySelectorPageState();
}

class _CurrencySelectorPageState extends State<CurrencySelectorPage> {
  static const List<_CurrencyOption> _currencies = [
    _CurrencyOption('USD', 'US Dollar', r'$'),
    _CurrencyOption('EUR', 'Euro', '€'),
    _CurrencyOption('EGP', 'Egyptian Pound', 'E£'),
    _CurrencyOption('GBP', 'British Pound', '£'),
    _CurrencyOption('JPY', 'Japanese Yen', '¥'),
    _CurrencyOption('SAR', 'Saudi Riyal', 'ر.س'),
    _CurrencyOption('AED', 'UAE Dirham', 'د.إ'),
    _CurrencyOption('INR', 'Indian Rupee', '₹'),
    _CurrencyOption('CAD', 'Canadian Dollar', r'C$'),
    _CurrencyOption('AUD', 'Australian Dollar', r'A$'),
  ];

  String? _selectedCode;
  String? _savedCode;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _hasChanged =>
      _selectedCode != null && _selectedCode != _savedCode;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await RenterApi.getUserById(widget.id);
      if (!mounted) return;

      final code = data['currency']?.toString().toUpperCase();
      setState(() {
        _selectedCode = _currencies.any((currency) => currency.code == code)
            ? code
            : null;
        _savedCode = _selectedCode;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Currency load error: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'We could not load your currency preference. Please try again.';
      });
    }
  }

  Future<void> _saveCurrency() async {
    if (!_hasChanged || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await RenterApi.updateCurrency(widget.id, _selectedCode!);
      if (!mounted) return;

      final selected = _selectedCode;
      setState(() {
        _savedCode = selected;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Currency updated successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF166534),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, selected);
    } catch (error) {
      debugPrint('Currency update error: $error');
      if (!mounted) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Could not update currency. Please try again.'),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          _CurrencyHeader(onBack: () => Navigator.maybePop(context)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _CurrencyLoadingState();

    if (_errorMessage != null) {
      return _CurrencyErrorState(
        message: _errorMessage!,
        onRetry: _getUserData,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 700 ? 32.0 : 16.0;

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24,
                  horizontalPadding,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _InformationCard(),
                        const SizedBox(height: 25),
                        const Text(
                          'Available currencies',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Choose the currency used to display prices throughout the app.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _CurrencyGrid(
                          currencies: _currencies,
                          selectedCode: _selectedCode,
                          onSelected: (code) {
                            setState(() => _selectedCode = code);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _SaveArea(
              selectedCurrency: _currencyForCode(_selectedCode),
              hasChanged: _hasChanged,
              isSaving: _isSaving,
              onSave: _saveCurrency,
            ),
          ],
        );
      },
    );
  }

  _CurrencyOption? _currencyForCode(String? code) {
    if (code == null) return null;
    for (final currency in _currencies) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}

class _CurrencyOption {
  final String code;
  final String name;
  final String symbol;

  const _CurrencyOption(this.code, this.name, this.symbol);
}

class _CurrencyHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _CurrencyHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 22),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  fixedSize: const Size(44, 44),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display Currency',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Personalize how prices appear',
                      style: TextStyle(
                        color: Color(0xFFC7D7FE),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.currency_exchange_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoIcon(),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prices made familiar',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Car prices and deposits will be converted to your selected currency.',
                  style: TextStyle(
                    color: Color(0xFF3B5998),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoIcon extends StatelessWidget {
  const _InfoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.info_outline_rounded, color: _primary, size: 21),
    );
  }
}

class _CurrencyGrid extends StatelessWidget {
  final List<_CurrencyOption> currencies;
  final String? selectedCode;
  final ValueChanged<String> onSelected;

  const _CurrencyGrid({
    required this.currencies,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: currencies.map((currency) {
            return SizedBox(
              width: itemWidth,
              child: _CurrencyTile(
                currency: currency,
                selected: selectedCode == currency.code,
                onTap: () => onSelected(currency.code),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  final _CurrencyOption currency;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyTile({
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '${currency.name}, ${currency.code}',
      child: Material(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _primary : _border,
                width: selected ? 1.8 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1F1D4ED8),
                        blurRadius: 16,
                        offset: Offset(0, 5),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x0A0F172A),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? _primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            currency.symbol,
                            style: TextStyle(
                              color: selected ? Colors.white : _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currency.code,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: _primary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveArea extends StatelessWidget {
  final _CurrencyOption? selectedCurrency;
  final bool hasChanged;
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveArea({
    required this.selectedCurrency,
    required this.hasChanged,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            children: [
              if (selectedCurrency != null) ...[
                Container(
                  width: 45,
                  height: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    selectedCurrency!.symbol,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected currency',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${selectedCurrency!.code} · ${selectedCurrency!.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const Expanded(
                  child: Text(
                    'Choose a currency to continue',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: hasChanged && !isSaving ? onSave : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: _muted,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 19),
                            SizedBox(width: 7),
                            Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CurrencyErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  color: Color(0xFFDC2626),
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Unable to load currencies',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 23),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyLoadingState extends StatelessWidget {
  const _CurrencyLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDF5),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const SizedBox(height: 28),
              const _LoadingBar(width: 190, height: 20),
              const SizedBox(height: 10),
              const _LoadingBar(width: 310, height: 12),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 132,
                  ),
                  itemCount: 6,
                  itemBuilder: (_, __) => Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  final double width;
  final double height;

  const _LoadingBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
