import 'package:expensetracker_app/services/auth.dart';
import 'package:expensetracker_app/views/pages/forgotpassword_page.dart';
import 'package:expensetracker_app/views/pages/register_page.dart';
import 'package:expensetracker_app/views/widgets/navbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Login page for email/password and Google sign in
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers to read text field input
  TextEditingController emailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();

  // UI states
  bool showPassword = true; // controls password visibility
  bool isEmailLoading = false; // loading state for email login
  bool isGoogleLoading = false; // loading state for Google login

  // Handle email + password login
  Future<void> login() async {
    // Hide keyboard before starting login
    FocusScope.of(context).unfocus();

    // Read and trim user input
    String email = emailcontroller.text.trim();
    String password = passwordcontroller.text;

    // Check if any field is empty
    if (email.isEmpty || password.isEmpty) {
      showSnackBar("Please fill in all fields", isError: true);
      return;
    }

    // Check if email format looks valid
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      showSnackBar("Enter a valid email address", isError: true);
      return;
    }

    // Start loading state for email login button
    setState(() => isEmailLoading = true);

    try {
      // Sign in with Firebase email/password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Stop if widget is already removed
      if (!mounted) return;

      // Show success message
      showSnackBar("Login successful", isError: false);

      // Move to main app page after login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => NavbarWidget(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Default error message
      String message = "Login failed";

      // Convert Firebase error codes into user-friendly messages
      switch (e.code) {
        case 'invalid-credential':
          message = "Invalid email or password";
          break;
        case 'user-not-found':
          message = "No account found with this email";
          break;
        case 'wrong-password':
          message = "Incorrect password";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Try again later";
          break;
        case 'network-request-failed':
          message = "No internet connection";
          break;
      }

      // Show error message
      showSnackBar(message, isError: true);
    } finally {
      // Stop loading no matter success or fail
      if (mounted) {
        setState(() => isEmailLoading = false);
      }
    }
  }

  // Handle Google sign in
  Future<void> _signInWithGoogle() async {
    // Start loading state for Google button
    setState(() => isGoogleLoading = true);

    try {
      // Call custom Google auth service
      final userCredential = await GoogleSignInService.signInWithGoogle();

      // Success handling can be added here if needed
      if (userCredential != null && mounted) {}
    } catch (e) {
      if (!mounted) return;

      // Show error if Google sign in fails
      showSnackBar("Google sign-in failed", isError: true);
    } finally {
      // Stop loading state
      if (mounted) {
        setState(() => isGoogleLoading = false);
      }
    }
  }

  // Reusable snackbar helper
  void showSnackBar(String text, {required bool isError}) {
    // Get current ScaffoldMessenger
    final messenger = ScaffoldMessenger.of(context);

    // Remove any existing snackbar first
    messenger.hideCurrentSnackBar();

    // Show new snackbar
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers to avoid memory leaks
    emailcontroller.dispose();
    passwordcontroller.dispose();
    super.dispose();
  }

  // Main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // move UI when keyboard appears
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // Background gradient for the whole page
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFF3B82F6)],
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
                child: Column(
                  children: [
                    const SizedBox(height: 80),

                    // App logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        "assets/images/logo.png",
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // App name
                    const Text(
                      "Voxpense",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    // App subtitle
                    const Text(
                      "Smart expense tracking with AI",
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),

                    const SizedBox(height: 40),

                    // Main login card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          // Email input field
                          _inputField(
                            icon: Icons.email_outlined,
                            hint: "Email address",
                            controller: emailcontroller,
                          ),

                          const SizedBox(height: 16),

                          // Password input field
                          _inputField(
                            icon: Icons.lock_outline,
                            hint: "Password",
                            controller: passwordcontroller,
                            obscureText: showPassword,

                            // Show/hide password button
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

                          // Forgot password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Forgot password?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Email login button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isEmailLoading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isEmailLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF9333EA),
                                      ),
                                    )
                                  : const Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF9333EA),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Divider between email login and Google sign in
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

                          // Google sign in button
                          GestureDetector(
                            onTap: isGoogleLoading ? null : _signInWithGoogle,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
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
                                      fontSize: 15,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Register page link
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return RegisterPage();
                              },
                            ),
                          );
                        },
                        child: RichText(
                          text: const TextSpan(
                            text: "Already have an account?  ",
                            style: TextStyle(color: Colors.white70),
                            children: [
                              TextSpan(
                                text: "Sign Up",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Reusable styled input field
  Widget _inputField({
    required IconData icon,
    required String hint,
    TextEditingController? controller,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,

          // Inner spacing for better alignment
          contentPadding: const EdgeInsets.symmetric(vertical: 16),

          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}