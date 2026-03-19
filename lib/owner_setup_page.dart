import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- Added to talk to the database!
import 'owner_home.dart';

class OwnerSetupPage extends StatefulWidget {
  const OwnerSetupPage({super.key});

  @override
  State<OwnerSetupPage> createState() => _OwnerSetupPageState();
}

class _OwnerSetupPageState extends State<OwnerSetupPage> {
  final _formKey = GlobalKey<FormState>();

  String _storeName = '';
  String _storeAddress = '';
  String _contactNumber = '';
  String? _storeType;

  bool _isLoading = false; // <-- Keeps track of whether we are currently saving

  final List<String> _storeTypes = ['Restaurant', 'Café', 'Grocery Store'];

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  // --- FIREBASE: Save Data & Finish Setup ---
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _isLoading = true); // Start the loading spinner

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {

          // Push all the store details to this specific owner's database file
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'storeName': _storeName,
            'storeType': _storeType,
            'storeAddress': _storeAddress,
            'contactNumber': _contactNumber,
            'isSetupComplete': true, // 🌟 THE MAGIC FIX: This stops the setup screen from looping!
          });

          // Success! Teleport them to their new dashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OwnerHomePage()),
            );
          }
        }
      } catch (e) {
        // If something goes wrong (e.g. no internet), show an error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save setup: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false); // Stop the spinner if it failed
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: culinaeCream,
      appBar: AppBar(
        backgroundColor: culinaeCream,
        elevation: 0,
        title: const Text('Store Setup', style: TextStyle(color: culinaeBrown, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Culinae! 🍽️',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: culinaeBrown),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Let\'s get your business set up so customers can start finding you.',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 32),

                _buildInputField(
                  label: 'Store Name',
                  hint: 'e.g. The Rustic Oven',
                  icon: Icons.storefront,
                  onSaved: (value) => _storeName = value!,
                  validator: (value) => value!.isEmpty ? 'Please enter a store name' : null,
                ),
                const SizedBox(height: 20),

                const Text('Store Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: culinaeBrown)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: _inputStyle(hint: 'Select your business type', icon: Icons.category),
                  items: _storeTypes.map((String type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (newValue) => setState(() => _storeType = newValue),
                  onSaved: (value) => _storeType = value,
                  validator: (value) => value == null ? 'Please select a store type' : null,
                ),
                const SizedBox(height: 20),

                _buildInputField(
                  label: 'Store Address',
                  hint: 'Full street address',
                  icon: Icons.location_on,
                  onSaved: (value) => _storeAddress = value!,
                  validator: (value) => value!.isEmpty ? 'Please enter an address' : null,
                ),
                const SizedBox(height: 20),

                _buildInputField(
                  label: 'Contact Number',
                  hint: 'Phone number for customers',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  onSaved: (value) => _contactNumber = value!,
                  validator: (value) => value!.isEmpty ? 'Please enter a contact number' : null,
                ),
                const SizedBox(height: 40),

                // Submit Button with Loading State
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: culinaeBrown,
                      foregroundColor: culinaeCream,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: culinaeCream, strokeWidth: 3)
                    )
                        : const Text('Complete Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: culinaeBrown)),
        const SizedBox(height: 8),
        TextFormField(
          keyboardType: keyboardType,
          decoration: _inputStyle(hint: hint, icon: icon),
          validator: validator,
          onSaved: onSaved,
        ),
      ],
    );
  }

  InputDecoration _inputStyle({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: culinaeBrown),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffeaeaea))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: culinaeBrown, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }
}