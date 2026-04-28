import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expensetracker_app/services/auth.dart';
import 'package:expensetracker_app/services/auth_wrapper.dart';
import 'package:expensetracker_app/views/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Register page for creating a new user account
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers to read user input from text fields
  TextEditingController namecontroller = TextEditingController();
  TextEditingController emailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  // UI states
  bool showPassword = true; // toggle password visibility
  bool showConfirmPassword = true; // toggle confirm password visibility
  bool isEmailLoading = false; // loading state for register button
  bool isGoogleLoading = false; // loading state for Google sign-in

  // Handle email registration
  Future<void> registration() async {
    // Get and trim user input
    String name = namecontroller.text.trim();
    String email = emailcontroller.text.trim();
    String password = passwordcontroller.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // Check if required fields are empty
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showSnackBar("Please fill in all fields", isError: true);
      return;
    }

    // Check if passwords match
    if (password != confirmPassword) {
      showSnackBar("Passwords do not match", isError: true);
      return;
    }

    // Start loading state
    setState(() => isEmailLoading = true);

    try {
      // Create user using Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      User user = userCredential.user!;

      // Save additional user data into Firestore
      await FirebaseFirestore.instance.collection("Users").doc(user.uid).set({
        "uid": user.uid,
        "name": name,
        "email": email,
        "imgURL": "", // placeholder for profile image
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Navigate to login page after successful registration
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Handle Firebase errors and show user-friendly messages
      if (e.code == 'weak-password') {
        showSnackBar("Password must be at least 6 characters", isError: true);
      } else if (e.code == 'email-already-in-use') {
        showSnackBar("Account already exists", isError: true);
      } else if (e.code == 'invalid-email') {
        showSnackBar("Invalid email format", isError: true);
      } else {
        showSnackBar("Registration failed", isError: true);
      }
    } finally {
      // Stop loading state
      if (mounted) setState(() => isEmailLoading = false);
    }
  }

  // Handle Google sign-in
  Future<void> signInWithGoogle(BuildContext context) async {
    // Start loading state
    setState(() => isGoogleLoading = true);

    try {
      // Call Google authentication service
      await GoogleSignInService.signInWithGoogle();

      if (!context.mounted) return;

      // Navigate to AuthWrapper after successful login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      // Show error if Google sign-in fails
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google Sign-In failed: $e")));
    } finally {
      // Stop loading state
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  // Reusable snackbar function
  void showSnackBar(String text, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    namecontroller.dispose();
    emailcontroller.dispose();
    passwordcontroller.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // adjust layout when keyboard appears
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // Background gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF14B8A6)],
          ),
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Main content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Page title
                          const Text(
                            "Create Account",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subtitle
                          const Text(
                            "Join us to start managing your expenses smartly",
                            style: TextStyle(color: Colors.white70),
                          ),

                          const SizedBox(height: 32),

                          // Name input
                          _inputField(
                            icon: Icons.person_outline,
                            hint: "Full name",
                            controller: namecontroller,
                          ),

                          const SizedBox(height: 16),

                          // Email input
                          _inputField(
                            icon: Icons.mail_outline,
                            hint: "Email address",
                            controller: emailcontroller,
                          ),

                          const SizedBox(height: 16),

                          // Password input
                          _inputField(
                            icon: Icons.lock_outline,
                            hint: "Password",
                            controller: passwordcontroller,
                            obscureText: showPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  showPassword = !showPassword;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Confirm password input
                          _inputField(
                            icon: Icons.lock_outline,
                            hint: "Confirm password",
                            controller: confirmPasswordController,
                            obscureText: showConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  showConfirmPassword =
                                      !showConfirmPassword;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Register button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed:
                                  isEmailLoading ? null : registration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isEmailLoading
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF2563EB),
                                    )
                                  : const Text(
                                      "Create Account",
                                      style: TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Divider
                          Row(
                            children: const [
                              Expanded(child: Divider(color: Colors.white70)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  "or continue with",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white70)),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Google sign-in button
                          GestureDetector(
                            onTap: isGoogleLoading
                                ? null
                                : () => signInWithGoogle(context),
                            child: Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/google.png',
                                    width: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Google",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Login redirect link
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: RichText(
                                text: const TextSpan(
                                  text: "Already have an account?  ",
                                  style: TextStyle(color: Colors.white70),
                                  children: [
                                    TextSpan(
                                      text: "Sign In",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration:
                                            TextDecoration.underline,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Reusable input field widget
  Widget _inputField({
    required IconData icon,
    required String hint,
    TextEditingController? controller,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        textAlignVertical: TextAlignVertical.center,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}