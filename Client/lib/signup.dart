import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();
  final _licenseController = TextEditingController();
  final _occupationController = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _selectedGender;
  String? _selectedNationality;
  bool _acceptedTerms = false;

  Future<void> submitSignupForm() async {
  final url = Uri.parse('http://10.0.2.2:8000/user/create');
  final payload = {
    "username": _usernameController.text,
    "email": _emailController.text,
    "password": _passwordController.text,
    "type": "Renter",
    "hasAcceptedTerms": _acceptedTerms,
    "name":
        "${_firstNameController.text} ${_middleNameController.text} ${_lastNameController.text}",
    "phoneNumber": _phoneController.text,
    "birthDate": _selectedBirthDate?.toIso8601String(),
    "gender": _selectedGender,
    "nationality": _selectedNationality,
    "idCardNumber": _idCardController.text,
    "drivingLicenseNumber": _licenseController.text,
    "occupation": _occupationController.text,
  };

  print("🚀 Sending data: $payload");

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  print("🔁 Response status: ${response.statusCode}");
  print("📦 Response body: ${response.body}");

if (response.statusCode == 200 || response.statusCode == 201) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created successfully')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Signup failed: ${response.body}')),
    );
  }
}


Future<List<Map<String, dynamic>>> fetchExistingUsers() async {
  final url = Uri.parse('http://10.0.2.2:8000/renter/getAll'); // Update to your actual API if needed

  try {
    final response = await http.get(url);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> usersJson = jsonDecode(response.body);
      return usersJson.cast<Map<String, dynamic>>();
    } else {
      print('❌ Failed to fetch users. Status: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    print('❗ Error fetching users: $e');
    return [];
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Create Account'),
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Welcome to Diamond Car',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Sign up to book your first ride!',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 24),

                // Account Info
                const Text(
                  'Account Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildField(controller: _usernameController, label: 'Username', icon: Icons.person),
                const SizedBox(height: 12),
                _buildField(controller: _emailController, label: 'Email', icon: Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildField(controller: _passwordController, label: 'Password', icon: Icons.lock, obscureText: true),
                const SizedBox(height: 12),
                _buildField(controller: _confirmPasswordController, label: 'Re-enter Password', icon: Icons.lock_outline, obscureText: true,
                  validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null),
                const SizedBox(height: 24),

                // Personal Info
                const Text(
                  'Personal Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildField(controller: _firstNameController, label: 'First Name', icon: Icons.account_box)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildField(controller: _middleNameController, label: 'Middle Name', icon: Icons.account_box)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildField(controller: _lastNameController, label: 'Last Name', icon: Icons.account_box)),
                  ],
                ),
                const SizedBox(height: 12),
                // Birthdate picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _selectedBirthDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthdate',
                      prefixIcon: const Icon(Icons.calendar_today),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_selectedBirthDate == null ? 'Select Date' : _selectedBirthDate!.toLocal().toString().split(' ')[0]),
                  ),
                ),
                const SizedBox(height: 12),
                // Gender dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _selectedGender = v),
                  validator: (v) => v == null ? 'Gender is required' : null,
                ),
                const SizedBox(height: 12),
                // Nationality dropdown
                DropdownSearch<String>(
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  items: const ['Egypt','United States','Germany','France','India','China','Japan','Canada','Brazil','Australia','South Africa','Saudi Arabia','Italy','United Kingdom','Mexico','Turkey','Argentina','UAE','Spain','Netherlands'],
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Nationality',
                      prefixIcon: const Icon(Icons.flag),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  onChanged: (v) => setState(() => _selectedNationality = v),
                  validator: (v) => v == null ? 'Nationality is required' : null,
                ),
                const SizedBox(height: 12),
                _buildField(controller: _phoneController, label: 'Phone Number', icon: Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildField(controller: _idCardController, label: 'ID Card Number', icon: Icons.credit_card),
                const SizedBox(height: 12),
                _buildField(controller: _licenseController, label: 'Driving License Number', icon: Icons.drive_eta),
                const SizedBox(height: 12),
                _buildField(controller: _occupationController, label: 'Occupation', icon: Icons.work),
                const SizedBox(height: 16),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I agree to the Terms and Conditions.'),
                  value: _acceptedTerms,
                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        if (!_acceptedTerms) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept terms to continue')));
                          return;
                        }
                        submitSignupForm();
                      }
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Sign Up', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text("Already have an account? Log in"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator ?? (val) => val == null || val.isEmpty ? '$label is required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
      ),
    );
  }
}
