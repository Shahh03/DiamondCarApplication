import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../api/payment_methods_api.dart';

class PaymentMethodsPage extends StatefulWidget {
  final String renterId;

  const PaymentMethodsPage({
    super.key,
    required this.renterId,
  });

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  static const _primary = Color(0xFF1D4ED8);
  static const _background = Color(0xFFF5F7FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  List<Map<String, dynamic>> _cards = [];
  String? _defaultPaymentMethodId;
  bool _isLoading = true;
  bool _isAdding = false;
  String? _busyCardId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final result = await PaymentMethodsApi.getSavedCards(widget.renterId);
      final rawCards = result['paymentMethods'];

      if (!mounted) return;
      setState(() {
        _cards = rawCards is List
            ? rawCards
                .whereType<Map>()
                .map((card) => Map<String, dynamic>.from(card))
                .toList()
            : <Map<String, dynamic>>[];
        _defaultPaymentMethodId =
            result['defaultPaymentMethodId']?.toString();
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _cleanError(error);
      });
    }
  }

  Future<void> _addCard() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);

    try {
      final setup =
          await PaymentMethodsApi.createSetupIntent(widget.renterId);
      final setupSecret = setup['setupIntentClientSecret']?.toString() ?? '';
      final customerId = setup['customerId']?.toString() ?? '';
      final customerSessionSecret =
          setup['customerSessionClientSecret']?.toString() ?? '';

      if (setupSecret.isEmpty ||
          customerId.isEmpty ||
          customerSessionSecret.isEmpty) {
        throw Exception('The server returned incomplete Stripe information.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setupSecret,
          customerId: customerId,
          customerSessionClientSecret: customerSessionSecret,
          merchantDisplayName: 'DiamondCar',
          returnURL: 'diamondcar://stripe-redirect',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      final hadNoCards = _cards.isEmpty;
      await _loadCards();

      if (hadNoCards &&
          _cards.isNotEmpty &&
          _defaultPaymentMethodId == null) {
        await _setDefault(_cards.first['id']?.toString() ?? '', silent: true);
      }

      if (mounted) _showMessage('Card added successfully.');
    } on StripeException catch (error) {
      final message = error.error.localizedMessage;
      if (message != null && message.trim().isNotEmpty) {
        _showMessage(message);
      }
    } catch (error) {
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _setDefault(
    String paymentMethodId, {
    bool silent = false,
  }) async {
    if (paymentMethodId.isEmpty) return;
    setState(() => _busyCardId = paymentMethodId);

    try {
      await PaymentMethodsApi.setDefaultCard(
        renterId: widget.renterId,
        paymentMethodId: paymentMethodId,
      );

      if (!mounted) return;
      setState(() => _defaultPaymentMethodId = paymentMethodId);
      if (!silent) _showMessage('Default card updated.');
    } catch (error) {
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => _busyCardId = null);
    }
  }

  Future<void> _confirmRemove(Map<String, dynamic> card) async {
    final paymentMethodId = card['id']?.toString() ?? '';
    if (paymentMethodId.isEmpty) return;

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Remove this card?'),
        content: Text(
          '${_brandLabel(card['brand'])} ending in ${card['last4']}. '
          'You can add it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep card'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;
    await _removeCard(paymentMethodId);
  }

  Future<void> _removeCard(String paymentMethodId) async {
    setState(() => _busyCardId = paymentMethodId);

    try {
      await PaymentMethodsApi.removeCard(
        renterId: widget.renterId,
        paymentMethodId: paymentMethodId,
      );
      await _loadCards();
      if (mounted) _showMessage('Card removed.');
    } catch (error) {
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => _busyCardId = null);
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _brandLabel(dynamic value) {
    final brand = value?.toString().toLowerCase() ?? 'card';
    switch (brand) {
      case 'visa':
        return 'Visa';
      case 'mastercard':
        return 'Mastercard';
      case 'amex':
        return 'American Express';
      case 'discover':
        return 'Discover';
      case 'diners':
        return 'Diners Club';
      case 'jcb':
        return 'JCB';
      case 'unionpay':
        return 'UnionPay';
      default:
        return 'Card';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Payment methods',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _primary,
          onRefresh: _loadCards,
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _isAdding ? null : _addCard,
            icon: _isAdding
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_card_rounded),
            label: Text(_isAdding ? 'Opening Stripe…' : 'Add a new card'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.cloud_off_rounded, size: 52, color: _muted),
          const SizedBox(height: 16),
          const Text(
            'Could not load your cards',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                });
                _loadCards();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          'Saved cards',
          style: TextStyle(
            color: _ink,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Choose a default card or remove one you no longer use.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 18),
        if (_cards.isEmpty) const _EmptyCardsCard(),
        ..._cards.map(_buildCard),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: _primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Card details are encrypted and stored by Stripe. '
                  'DiamondCar never stores your full card number or CVC.',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> card) {
    final id = card['id']?.toString() ?? '';
    final last4 = card['last4']?.toString() ?? '----';
    final month = (card['expMonth'] as num?)?.toInt();
    final year = (card['expYear'] as num?)?.toInt();
    final expiry = month == null || year == null
        ? 'Expiry unavailable'
        : 'Expires ${month.toString().padLeft(2, '0')}/$year';
    final isDefault = id == _defaultPaymentMethodId;
    final isBusy = id == _busyCardId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDefault ? const Color(0xFF93C5FD) : _border,
          width: isDefault ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.credit_card_rounded, color: _primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${_brandLabel(card['brand'])} •••• $last4',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  expiry,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Card options',
              icon: const Icon(Icons.more_vert_rounded, color: _muted),
              onSelected: (action) {
                if (action == 'default') _setDefault(id);
                if (action == 'remove') _confirmRemove(card);
              },
              itemBuilder: (_) => [
                if (!isDefault)
                  const PopupMenuItem(
                    value: 'default',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded),
                        SizedBox(width: 10),
                        Text('Make default'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Remove card'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyCardsCard extends StatelessWidget {
  const _EmptyCardsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PaymentMethodsPageState._border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.credit_card_off_outlined,
            color: _PaymentMethodsPageState._muted,
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            'No saved cards',
            style: TextStyle(
              color: _PaymentMethodsPageState._ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Add a card for a faster checkout next time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _PaymentMethodsPageState._muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
