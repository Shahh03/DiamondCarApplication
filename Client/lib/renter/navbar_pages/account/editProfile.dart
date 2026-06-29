import 'package:flutter/material.dart';
import '../../api/renter_api.dart';
import 'account.dart';

class EditProfilePage extends StatefulWidget {
  final String id;

  const EditProfilePage({super.key, required this.id});

  @override
  State<EditProfilePage> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
 


  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController nationalityController;
  late TextEditingController occupationController;
  late TextEditingController locationController;

  DateTime? birthDate;
  String? gender;

  Map<String, dynamic>? userData;
  bool isLoading = true;

  final List<String> genderOptions = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    nationalityController = TextEditingController();
    occupationController = TextEditingController();
    locationController = TextEditingController();
    getUserData();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    nationalityController.dispose();
    occupationController.dispose();
    locationController.dispose();
    super.dispose();
  }

 Future<void> getUserData() async {
  try {
    final data = await RenterApi.getUserById(widget.id);

    if (!mounted) return;

    setState(() {
      userData = data;

      final fullName = (data['name'] ?? '').toString().trim();
      final nameParts = fullName.split(' ');

      firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
      lastNameController.text =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      nationalityController.text = data['nationality'] ?? '';
      occupationController.text = data['occupation'] ?? '';
      locationController.text = data['location'] ?? '';
      gender = data['gender'];
      birthDate = DateTime.tryParse(data['birthDate'] ?? '');

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

  Future<void> saveChanges() async {
  if (!_formKey.currentState!.validate()) return;

  final firstName = firstNameController.text.trim();
  final lastName = lastNameController.text.trim();

  try {
    await RenterApi.updateRenterProfile(
      renterId: widget.id,
      name: '$firstName $lastName',
      nationality: nationalityController.text.trim(),
      occupation: occupationController.text.trim(),
      location: locationController.text.trim(),
      gender: gender,
      birthDate: birthDate,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RenterProfile(id: widget.id),
      ),
    );
  } catch (e) {
    debugPrint('Error updating profile: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(label, icon),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
        decoration: _inputDecoration(label, icon),
        validator: (val) {
          if (val == null || val.isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label, [IconData? icon]) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
appBar: AppBar(
                backgroundColor: Colors.blueAccent,

        title: const Text('Edit Profile'),
      ),      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(firstNameController, 'First Name', Icons.person),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(lastNameController, 'Last Name', Icons.person),
                            ),
                          ],
                        ),
                        _buildDropdown(
                          label: 'Nationality',
                          value: nationalityController.text.isNotEmpty ? nationalityController.text : null,
                           items: const ['Egypt','United States','Germany','France','India','China','Japan','Canada','Brazil','Australia','South Africa','Saudi Arabia','Italy','United Kingdom','Mexico','Turkey','Argentina','UAE','Spain','Netherlands'],
                          onChanged: (val) => setState(() => nationalityController.text = val ?? ''),
                          icon: Icons.flag,
                        ),
                        _buildTextField(occupationController, 'Occupation', Icons.work_outline),
                        _buildTextField(locationController, 'Location', Icons.location_on),
                        _buildDropdown(
                          label: 'Gender',
                          value: gender,
                          items: genderOptions,
                          onChanged: (val) => setState(() => gender = val),
                          icon: Icons.wc,
                        ),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: birthDate ?? DateTime(2000),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => birthDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: _inputDecoration('Birthdate', Icons.calendar_today),
                            child: Text(
                              birthDate == null
                                  ? 'Select Date'
                                  : birthDate!.toLocal().toString().split(' ')[0],
                              style: TextStyle(
                                color: birthDate == null ? Colors.grey : Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: saveChanges,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
