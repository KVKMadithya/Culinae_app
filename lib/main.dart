import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- Added to read the database!

import 'firebase_options.dart';
import 'splash_screen.dart';
import 'customer_home.dart';
import 'owner_home.dart'; // <-- Added!
import 'owner_setup_page.dart'; // <-- Added!
import 'role_selection_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CulinaeApp());
}

class CulinaeApp extends StatelessWidget {
  const CulinaeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Culinae',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF4A1F1F),
        fontFamily: 'Roboto',
      ),
      // We keep your splash screen as the very first thing the app shows!
      home: const SplashScreen(),
    );
  }
}

// --- The Smarter Bouncer ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 1. While checking Firebase Auth, show a quick loading circle
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF4A1F1F),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFFF3E3))),
          );
        }

        // 2. User is NOT logged in -> Send them to pick a role!
        if (!snapshot.hasData || snapshot.data == null) {
          return const RoleSelectionPage();
        }

        // 3. User IS logged in! Let's check the database to see WHO they are.
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
          builder: (context, userSnapshot) {

            // Show loading screen while reading the database
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF4A1F1F),
                body: Center(child: CircularProgressIndicator(color: Color(0xFFFFF3E3))),
              );
            }

            // If we successfully found their data
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              final role = data['role'];

              // If Customer -> Go to Customer App
              if (role == 'customer') {
                return const CustomerHomePage();
              }
              // If Owner -> Check if setup is done, then route to the right page!
              else if (role == 'owner') {
                final bool isSetupComplete = data.containsKey('isSetupComplete') && data['isSetupComplete'] == true;
                return isSetupComplete ? const OwnerHomePage() : const OwnerSetupPage();
              }
            }

            // Fallback just in case something breaks or their database file was deleted
            return const RoleSelectionPage();
          },
        );
      },
    );
  }
}