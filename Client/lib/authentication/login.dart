import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../renter/navbar_pages/home/home.dart';
import '../admin/dashboard.dart';
import '../provider/dashboard.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;

  Future<void> submitLoginForm() async {
  final url = Uri.parse('http://10.0.2.2:8000/user/login');

  final payload = {
    "identifier": _emailController.text.trim(),  // works for email or username
    "password": _passwordController.text.trim(),
  };



  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Logging in...')),
  );

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );



if (response.statusCode == 200 || response.statusCode == 201) {
  final data = jsonDecode(response.body);
  final user = data['user'];
  final String id = user['_id'];
  final String type = user['type'];

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Login successful!')),
  );

  await Future.delayed(const Duration(milliseconds: 500));

  // Navigate to the corresponding dashboard
  if (type == 'Renter') {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => RenterHome(renterId: id),
    ),
  );
} else if (type == 'Provider') {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => ProviderDashboard(id: id),
    ),
  );
} else if (type == 'Admin') {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => AdminDashboard(id: id),
    ),
  );
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Unknown user type")),
  );
}

}
 else {
      print("❌ Login failed: ${response.body}");
      ScaffoldMessenger.of(context).clearSnackBars();

      String errorMessage = 'Login failed. Please try again.';
      try {
        final data = jsonDecode(response.body);
        if (data['message'] != null) {
          errorMessage = data['message'];
        }
      } catch (e) {
        print("Failed to parse error message: $e");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  } catch (e) {
    print("🚨 Error: $e");
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('An error occurred during login.')),
    );
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
        title: const Text('Login'),
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
            boxShadow: const [
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
                    'Welcome Back!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Log in to continue',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Account Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                _buildField(
                  controller: _emailController,
                  label: 'Email or Username',
                  icon: Icons.email,
                ),
                const SizedBox(height: 12),

                _buildField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  obscureText: true,
                ),
                const SizedBox(height: 12),

               /* CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remember me'),
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 24),*/

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        if (_emailController.text.isEmpty ||
                            _passwordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please fill in both email and password')),
                          );
                          return;
                        }
                        submitLoginForm();
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Log In', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/signup');
                    },
                    child: const Text("Don’t have an account? Sign up"),
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
      validator: validator ??
          (val) => val == null || val.isEmpty ? '$label is required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
      ),
    );
  }
}
