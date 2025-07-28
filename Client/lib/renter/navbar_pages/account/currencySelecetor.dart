import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      final url = Uri.parse('http://10.0.2.2:8000/user/${widget.id}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          selectedCurrencyCode = data['currency'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> saveCurrency() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/renter/updateCurrency/${widget.id}');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'currency': selectedCurrencyCode}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Currency updated successfully')),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed to update currency');
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating currency')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyCodes = currencyMap.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select Currency')),
      backgroundColor: Colors.blueAccent,
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
