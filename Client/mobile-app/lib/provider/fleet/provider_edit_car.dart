import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api/provider_fleet_api.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';

class ProviderEditCarPage extends StatefulWidget {
  final String providerId;
  final Map<String, dynamic> variant;

  const ProviderEditCarPage({
    super.key,
    required this.providerId,
    required this.variant,
  });

  @override
  State<ProviderEditCarPage> createState() => _ProviderEditCarPageState();
}

class _ProviderEditCarPageState extends State<ProviderEditCarPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _colorController;
  late final TextEditingController _registrationController;
  late final TextEditingController _dailyPriceController;
  late final TextEditingController _depositController;
  late final TextEditingController _insuranceCompanyController;
  late final TextEditingController _policyNumberController;

  late bool _isAvailable;
  DateTime? _insuranceExpiryDate;
  late List<String> _images;
  late List<String> _imagePublicIds;
  final List<XFile> _newImages = <XFile>[];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final insurance = _map(widget.variant['insuranceDetails']);
    _colorController = TextEditingController(text: _text(widget.variant['color']));
    _registrationController =
        TextEditingController(text: _text(widget.variant['registrationNumber']));
    _dailyPriceController =
        TextEditingController(text: _numberText(widget.variant['rentalPricePerDay']));
    _depositController =
        TextEditingController(text: _numberText(widget.variant['depositAmount']));
    _insuranceCompanyController =
        TextEditingController(text: _text(insurance['insuranceCompany']));
    _policyNumberController =
        TextEditingController(text: _text(insurance['policyNumber']));
    _insuranceExpiryDate = DateTime.tryParse(_text(insurance['expiryDate']));
    _isAvailable = widget.variant['isAvailable'] == true;
    _images = _stringList(widget.variant['images']);
    _imagePublicIds = _stringList(widget.variant['imagePublicIds']);
  }

  @override
  void dispose() {
    _colorController.dispose();
    _registrationController.dispose();
    _dailyPriceController.dispose();
    _depositController.dispose();
    _insuranceCompanyController.dispose();
    _policyNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 10 - _images.length - _newImages.length;
    if (remaining <= 0) {
      _showMessage('A vehicle can have a maximum of 10 images.');
      return;
    }

    try {
      final selected = await _picker.pickMultiImage(
        imageQuality: 85,
        limit: remaining,
      );
      if (!mounted || selected.isEmpty) return;

      // Keep an app-side limit as a safety net for OEM gallery apps that do
      // not fully enforce the limit supplied to the native photo picker.
      final currentPaths = _newImages.map((image) => image.path).toSet();
      final accepted = selected
          .where((image) => currentPaths.add(image.path))
          .take(remaining)
          .toList();

      if (accepted.isEmpty) {
        _showMessage('Those photos are already selected.');
        return;
      }

      setState(() => _newImages.addAll(accepted));

      if (selected.length > accepted.length) {
        _showMessage(
          'Only $remaining more photo${remaining == 1 ? '' : 's'} can be added.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not open your photos. ${_cleanError(error)}');
    }
  }

  Future<void> _chooseExpiryDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _insuranceExpiryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _insuranceExpiryDate = selected);
    }
  }

  Future<void> _removeExistingImage(int index) async {
    final confirmed = await _confirm(
      title: 'Remove image?',
      message: 'This image will be permanently removed from the vehicle.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    try {
      final result = await ProviderFleetApi.removeImage(
        carVariantId: _text(widget.variant['_id']),
        imageUrl: _images[index],
        imagePublicId: index < _imagePublicIds.length
            ? _imagePublicIds[index]
            : null,
      );
      if (!mounted) return;
      setState(() {
        _images = _stringList(result['images']);
        _imagePublicIds = _stringList(result['imagePublicIds']);
      });
      _showMessage('Image removed.');
    } catch (error) {
      _showMessage(_cleanError(error));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final variantId = _text(widget.variant['_id']);
      await ProviderFleetApi.updateCarVariant(
        carVariantId: variantId,
        color: _colorController.text,
        registrationNumber: _registrationController.text,
        rentalPricePerDay: num.parse(_dailyPriceController.text.trim()),
        depositAmount: num.parse(_depositController.text.trim()),
        isAvailable: _isAvailable,
        insuranceCompany: _insuranceCompanyController.text,
        policyNumber: _policyNumberController.text,
        insuranceExpiryDate: _insuranceExpiryDate,
      );

      if (_newImages.isNotEmpty) {
        await ProviderFleetApi.uploadImages(
          carVariantId: variantId,
          filePaths: _newImages.map((image) => image.path).toList(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(_cleanError(error));
    }
  }

  Future<void> _removeVehicle() async {
    final confirmed = await _confirm(
      title: 'Remove vehicle from fleet?',
      message:
          'The vehicle will disappear from your fleet and renter searches. '
          'It cannot be removed while it has an active or upcoming booking.',
      confirmLabel: 'Remove vehicle',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ProviderFleetApi.removeCarVariant(_text(widget.variant['_id']));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(_cleanError(error));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _moneyValidator(String? value, String label) {
    final number = num.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return '$label must be zero or greater';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final car = _map(widget.variant['car']);
    final name = [_text(car['brand']), _text(car['model'])]
        .where((value) => value.isNotEmpty)
        .join(' ');
    final currency = ProviderDataScope.of(context).currency;

    return Scaffold(
      backgroundColor: providerBackground,
      appBar: AppBar(
        title: const Text('Edit vehicle'),
        backgroundColor: providerBackground,
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                name.isEmpty ? 'Vehicle details' : name,
                style: const TextStyle(
                  color: providerInk,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _section(
                title: 'Vehicle information',
                children: [
                  TextFormField(
                    controller: _registrationController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Registration number'),
                    validator: (value) => _required(value, 'Registration number'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(labelText: 'Color'),
                    validator: (value) => _required(value, 'Color'),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available for rental'),
                    subtitle: Text(
                      _isAvailable
                          ? 'Renters can find and book this vehicle.'
                          : 'This vehicle is hidden from available cars.',
                    ),
                    value: _isAvailable,
                    onChanged: (value) => setState(() => _isAvailable = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Pricing ($currency)',
                children: [
                  TextFormField(
                    controller: _dailyPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Rental price per day'),
                    validator: (value) => _moneyValidator(value, 'Daily price'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _depositController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Deposit amount'),
                    validator: (value) => _moneyValidator(value, 'Deposit'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Insurance',
                children: [
                  TextFormField(
                    controller: _insuranceCompanyController,
                    decoration: const InputDecoration(labelText: 'Insurance company'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _policyNumberController,
                    decoration: const InputDecoration(labelText: 'Policy number'),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Expiry date'),
                    subtitle: Text(
                      _insuranceExpiryDate == null
                          ? 'Not set'
                          : DateFormat.yMMMd().format(_insuranceExpiryDate!),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _chooseExpiryDate,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Photos (${_images.length + _newImages.length}/10)',
                children: [
                  if (_images.isEmpty && _newImages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        'No vehicle photos yet.',
                        style: TextStyle(color: providerMuted),
                      ),
                    ),
                  if (_images.isNotEmpty || _newImages.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _images.length + _newImages.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final existing = index < _images.length;
                        final localIndex = index - _images.length;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: existing
                                  ? Image.network(
                                      _images[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image_outlined),
                                    )
                                  : Image.file(
                                      File(_newImages[localIndex].path),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filled(
                                visualDensity: VisualDensity.compact,
                                iconSize: 17,
                                onPressed: existing
                                    ? () => _removeExistingImage(index)
                                    : () => setState(
                                          () => _newImages.removeAt(localIndex),
                                        ),
                                icon: const Icon(Icons.close_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withOpacity(0.65),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _images.length + _newImages.length >= 10
                        ? null
                        : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      'Add photos (${10 - _images.length - _newImages.length} remaining)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save changes'),
                style: FilledButton.styleFrom(
                  backgroundColor: providerPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _removeVehicle,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove vehicle from fleet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return ProviderSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: providerInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  static List<String> _stringList(dynamic value) => value is List
      ? value.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList()
      : <String>[];

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _numberText(dynamic value) {
    if (value is num) return value.toString();
    return _text(value);
  }

  static String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}
