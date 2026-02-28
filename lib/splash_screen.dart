import 'dart:async';
import 'package:flutter/material.dart';
import 'role_selection_page.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeScale;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeScale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoleSelectionPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A1F1F), // maroon bg
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _slideUp,
              child: ScaleTransition(
                scale: _fadeScale,
                child: FadeTransition(
                  opacity: _fadeScale,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E3),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/icons/culinae_icon.png',
                          width: 140,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Culinae',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A1F1F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            FadeTransition(
              opacity: _fadeScale,
              child: const Text(
                'Cook. Taste. Love. Repeat',
                style: TextStyle(color: Colors.white70, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
