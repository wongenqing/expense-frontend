import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Page for users to change their password
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {

  // Controllers for password input fields
  final currentController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();

  // Loading state when updating password
  bool isLoading = false;

  // Toggle visibility for each password field
  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  // Track whether the user is email/password user
  bool isEmailUser = true;

  @override
  void initState() {
    super.initState();

    // Check if user is allowed to change password
    _checkAccess();
  }

  /// Check if the user is using Google login
  /// If yes → block password change
  Future<void> _checkAccess() async {
    final auth = FirebaseAuth.instance;

    // Refresh user data
    await auth.currentUser?.reload();

    if (!mounted) return;

    final user = auth.currentUser;

    // Check if logged in with Google
    bool isGoogle =
        user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    if (isGoogle) {
      // Show message and exit page
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password is managed by Google. Please change it in your Google account.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Close page after short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.pop(context);
      });

      return;
    }

    // Check if email/password login exists
    if (!mounted) return;

    setState(() {
      isEmailUser =
          user?.providerData.any((p) => p.providerId == 'password') ?? false;
    });
  }

  /// Show snackbar message (success or error)
  void showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 14)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Main logic to change password
  Future<void> changePassword() async {

    // Extra protection: block Google users
    final userCheck = FirebaseAuth.instance.currentUser;

    bool isGoogle =
        userCheck?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    if (isGoogle) {
      showSnack("Google users cannot change password here.", Colors.red);
      return;
    }

    // Get user input
    final current = currentController.text.trim();
    final newPass = newController.text.trim();
    final confirm = confirmController.text.trim();

    // Validate inputs
    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      showSnack("Please fill in all fields.", Colors.red);
      return;
    }

    if (newPass != confirm) {
      showSnack("New password and confirmation do not match.", Colors.red);
      return;
    }

    if (newPass.length < 6) {
      showSnack("New password must be at least 6 characters long.", Colors.red);
      return;
    }

    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;

      // Check session
      if (user == null || user.email == null) {
        showSnack("User session expired. Please log in again.", Colors.red);
        return;
      }

      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );

      await user.reauthenticateWithCredential(credential);

      // Prevent same password reuse
      if (current == newPass) {
        showSnack(
          "Your new password must be different from your current password.",
          Colors.red,
        );
        return;
      }

      // Update password
      await user.updatePassword(newPass);

      if (!mounted) return;

      // Success message
      showSnack("Your password has been updated successfully.", Colors.green);

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors
      if (e.code == 'invalid-credential') {
        showSnack("Invalid current password. Please try again.", Colors.red);
      } else if (e.code == 'user-mismatch') {
        showSnack("User verification failed. Please log in again.", Colors.red);
      } else if (e.code == 'requires-recent-login') {
        showSnack(
          "Please log out and log in again before changing your password.",
          Colors.red,
        );
      } else {
        showSnack(
          "An unexpected error occurred. Please try again later.",
          Colors.red,
        );
      }
    } catch (e) {
      showSnack("Something went wrong. Please try again.", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  /// Reusable password input field
  Widget passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field label
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black),
          ),

          const SizedBox(height: 8),

          // Input row
          Row(
            children: [
              const Icon(Icons.lock, size: 18, color: Colors.grey),
              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Enter ${label.toLowerCase()}",
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // Toggle password visibility
              IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: toggle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [

          // Header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFEC4899)],
              ),
            ),
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(width: 10),

                // Title
                const Text(
                  "Change Password",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Body content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [

                  // Warning for non-email users
                  if (!isEmailUser)
                    const Text(
                      "Password cannot be changed for Google login.",
                      style: TextStyle(color: Colors.red),
                    ),

                  const SizedBox(height: 10),

                  // Input fields
                  passwordField(
                    label: "Current Password",
                    controller: currentController,
                    obscure: obscureCurrent,
                    toggle: () =>
                        setState(() => obscureCurrent = !obscureCurrent),
                  ),

                  passwordField(
                    label: "New Password",
                    controller: newController,
                    obscure: obscureNew,
                    toggle: () =>
                        setState(() => obscureNew = !obscureNew),
                  ),

                  passwordField(
                    label: "Confirm New Password",
                    controller: confirmController,
                    obscure: obscureConfirm,
                    toggle: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),

                  const SizedBox(height: 20),

                  // Update button
                  GestureDetector(
                    onTap: isLoading ? null : changePassword,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      alignment: Alignment.center,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Update Password",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}