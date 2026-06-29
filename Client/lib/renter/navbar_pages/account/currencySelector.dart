import 'package:flutter/material.dart';
import '../../api/renter_api.dart';

class CurrencySelectorPage extends StatefulWidget {
  final String id;

  const CurrencySelectorPage({super.key, required this.id});

  @override
  State<CurrencySelectorPage> createState() => _CurrencySelectorPageState();
}

class _CurrencySelectorPageState extends State<CurrencySelectorPage> {
  // Map of currency codes to display labels
  final Map<String, String> currencyMap = {
    'USD': 'USD - \$',
    'EUR': 'EUR - €',
    'EGP': 'EGP - E£',
    'GBP': 'GBP - £',
    'JPY': 'JPY - ¥',
    'SAR': 'SAR - ر.س',
    'AED': 'AED - د.إ',
    'INR': 'INR - ₹',
    'CAD': 'CAD - C\$',
    'AUD': 'AUD - A\$',
  };

  String? selectedCurrencyCode;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

 Future<void> getUserData() async {
  try {
    final data = await RenterApi.getUserById(widget.id);

    if (!mounted) return;

    setState(() {
      selectedCurrencyCode = data['currency'];
      isLoading = false;
    });
  } catch (e) {
    debugPrint('Error: $e');

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }
}

 Future<void> saveCurrency() async {
  if (selectedCurrencyCode == null) return;

  try {
    await RenterApi.updateCurrency(widget.id, selectedCurrencyCode!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Currency updated successfully')),
    );

    Navigator.pop(context);
  } catch (e) {
    debugPrint('Error: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error updating currency')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final currencyCodes = currencyMap.keys.toList();

    return Scaffold(

      appBar: AppBar(backgroundColor: Colors.blueAccent, title: const Text('Select Currency')),
      body: isLoading
      
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose your preferred currency:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: currencyCodes.map((code) {
                      return ChoiceChip(
                        label: Text(currencyMap[code]!),
                        selected: selectedCurrencyCode == code,
                        selectedColor: Colors.blueAccent,
                        labelStyle: TextStyle(
                          color: selectedCurrencyCode == code ? Colors.white : Colors.black,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedCurrencyCode = code;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: selectedCurrencyCode == null ? null : saveCurrency,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
