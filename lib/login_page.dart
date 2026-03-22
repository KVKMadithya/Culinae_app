import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'customer_home.dart';
import 'owner_home.dart';
import 'admin_home.dart';
import 'signin_page.dart';
import 'owner_setup_page.dart';

enum UserRole { customer, owner }

class LoginPage extends StatefulWidget {
  final UserRole role;

  const LoginPage({super.key, required this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  final _auth = FirebaseAuth.instance;

  // ==========================================================
  // 📧 STANDARD EMAIL & PASSWORD LOGIN
  // ==========================================================
  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _routeUser(userCredential.user!.uid);

    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================
  // 🚦 THE TRAFFIC COP & SECURITY CHECK (Routing Logic)
  // ==========================================================
  Future<void> _routeUser(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!doc.exists) throw Exception('User data not found in database.');

    final data = doc.data() as Map<String, dynamic>;
    final role = data['role'];

    // --- NEW: THE BAN CHECK ---
    final isBanned = data['isBanned'] == true;

    if (!mounted) return;

    // 🛑 If the user is banned, kick them out immediately!
    if (isBanned) {
      await _auth.signOut(); // Force log them out of Firebase
      _showError('This account has been suspended by an Administrator.');
      return; // Stop the code here so they don't get routed into the app
    }

    // --- THE ADMIN ROUTE ---
    if (role == 'admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomePage()));
    }
    // --- CUSTOMER ROUTE ---
    else if (role == 'customer') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerHomePage()));
    }
    // --- OWNER ROUTE ---
    else if (role == 'owner') {
      final bool isSetupComplete = data.containsKey('isSetupComplete') && data['isSetupComplete'] == true;
      if (isSetupComplete) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerHomePage()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerSetupPage()));
      }
    }
    else {
      throw Exception('Invalid user role assigned.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.role == UserRole.owner;
    const Color culinaeBrown = Color(0xFF4A1F1F);
    const Color culinaeCream = Color(0xFFFFF3E3);

    return Scaffold(
      backgroundColor: culinaeBrown,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                isOwner ? 'Store Owner Login' : 'Welcome Back',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 40),

              _inputField(controller: _emailController, hint: 'Email', icon: Icons.email_outlined),
              const SizedBox(height: 16),
              _inputField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 24),

              // Standard Login Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: culinaeCream,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: culinaeBrown)
                      : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: culinaeBrown)),
                ),
              ),

              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SignInPage(role: isOwner ? 'owner' : 'customer'))),
                    child: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.bold, color: culinaeCream)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint, prefixIcon: Icon(icon), suffixIcon: suffix, filled: true, fillColor: const Color(0xFFFFF3E3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}