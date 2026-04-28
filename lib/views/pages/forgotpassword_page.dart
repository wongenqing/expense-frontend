import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Screen that allows users to request a password reset email
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Controller to capture user email input
  final TextEditingController emailController = TextEditingController();

  // Indicates whether the reset request is in progress
  bool loading = false;

  /// Sends password reset email using Firebase Authentication
  Future<void> resetPassword() async {
    String email = emailController.text.trim();

    // Validate email input
    if (email.isEmpty) {
      showSnackBar("Please enter your email", isError: true);
      return;
    }

    try {
      setState(() => loading = true);

      // Trigger Firebase password reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      showSnackBar("Reset link sent! Check your email.", isError: false);
    } on FirebaseAuthException catch (e) {
      // Handle invalid email format error
      if (e.code == "invalid-email") {
        showSnackBar("Invalid email format", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  /// Displays a styled snackbar for feedback messages
  void showSnackBar(String text, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controller to prevent memory leaks
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,

      // Gradient background container
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff4f46e5), Color(0xff9333ea)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),

                  child: Column(
                    children: [

                      /// Back navigation button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Lock icon representing security/password
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 30),

                      /// Page title
                      const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 10),

                      /// Instruction text
                      const Text(
                        "Enter your email and we'll send you a reset link",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),

                      const SizedBox(height: 40),

                      /// Email input field
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            icon: Icon(
                              Icons.email_outlined,
                              color: Colors.white70,
                            ),
                            hintText: "Enter your email",
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      /// Button to trigger password reset
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xff4f46e5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),

                          // Disable button when loading
                          onPressed: loading ? null : resetPassword,

                          child: loading
                              // Loading indicator while request is in progress
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              // Default button text
                              : const Text(
                                  "Send Reset Link",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}