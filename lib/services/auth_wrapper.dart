import 'package:expensetracker_app/views/widgets/navbar_widget.dart';
import 'package:expensetracker_app/views/pages/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// This widget decides which screen to show based on authentication state
// It automatically switches between LoginPage and Navbar (main app)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {

    // Listen to Firebase authentication state changes in real-time
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {

        /// While checking authentication status (initial load)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        /// If user is logged in
        if (snapshot.hasData) {
          // Navigate to main app (bottom navigation page)
          return const NavbarWidget();
        }

        /// If user is NOT logged in
        // Show login page
        return const LoginPage();
      },
    );
  }
}