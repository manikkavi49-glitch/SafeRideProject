import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vanController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(); // NEW
  final TextEditingController _schoolController = TextEditingController();  // NEW
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _handleRegistration() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) return;
    
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;
      DatabaseReference ref = FirebaseDatabase.instance.ref("parents/$uid");

      await ref.set({
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "assigned_van": _vanController.text.trim(),
        "address": _addressController.text.trim(), // SAVING TO DB
        "school": _schoolController.text.trim(),   // SAVING TO DB
        "created_at": ServerValue.timestamp,
        "role": "parent"
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully!")),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Registration Failed")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.person_add_alt_1, size: 70, color: Colors.green),
              const SizedBox(height: 20),
              _buildTextField(_nameController, "Full Name", Icons.person),
              _buildTextField(_emailController, "Email", Icons.email),
              _buildTextField(_addressController, "Home Address", Icons.home),
              _buildTextField(_schoolController, "School Name", Icons.school),
              _buildTextField(_vanController, "Assigned Van ID", Icons.directions_bus),
              _buildTextField(_passwordController, "Password", Icons.lock, isObscure: true),
              const SizedBox(height: 25),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleRegistration,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Register", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}