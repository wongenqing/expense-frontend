import 'package:expensetracker_app/views/pages/currency_page.dart';
import 'package:expensetracker_app/views/pages/help_center_page.dart';
import 'package:expensetracker_app/views/pages/privacy_policy_page.dart';
import 'package:expensetracker_app/views/pages/profile_page.dart';
import 'package:expensetracker_app/views/pages/terms_of_service_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  /// Firebase authenticated user
  User? get user => FirebaseAuth.instance.currentUser;

  /// Profile image URL
  String? imgURL;

  /// Loading state for profile image
  bool isLoadingPhoto = true;

  @override
  void initState() {
    super.initState();
    loadProfilePhoto();
  }

  /// Fetch user profile photo from Firestore
  Future<void> loadProfilePhoto() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection("Users")
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        imgURL = doc.data()?["imgURL"];
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    if (!mounted) return;

    setState(() {
      isLoadingPhoto = false;
    });
  }

  /// Handles logout process with confirmation dialog
  Future<void> logout() async {
    final confirm = await _showLogoutDialog(context);

    if (!confirm) return;

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Displays logout confirmation dialog
  Future<bool> _showLogoutDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildLogoutDialog(context),
    );

    return result ?? false;
  }

  /// Logout confirmation dialog UI
  Widget _buildLogoutDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLogoutIcon(),
            const SizedBox(height: 16),
            const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Are you sure you want to logout?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildLogoutButtons(context),
          ],
        ),
      ),
    );
  }

  /// Logout icon widget
  Widget _buildLogoutIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.logout_rounded, color: Colors.red, size: 32),
    );
  }

  /// Logout action buttons
  Widget _buildLogoutButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: _buttonStyle(Colors.grey[300]!),
            child: const Text("Cancel",
                style: TextStyle(color: Colors.black, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _buttonStyle(Colors.red),
            child: const Text("Logout",
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  /// Common button styling
  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    );
  }

  /// Generates user initials from name or email
  String getInitials() {
    final name = user?.displayName;
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();

    final email = user?.email;
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();

    return "U";
  }

  /// Validates image URL format
  bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  /// Formats currency display name and symbol
  String _getCurrencyDisplay(String code, String symbol) {
    final names = {
      "MYR": "Malaysian Ringgit",
      "USD": "US Dollar",
      "EUR": "Euro",
      "GBP": "British Pound",
      "SGD": "Singapore Dollar",
      "JPY": "Japanese Yen",
      "CNY": "Chinese Yuan",
      "AUD": "Australian Dollar",
      "CAD": "Canadian Dollar",
      "CHF": "Swiss Franc",
    };

    final name = names[code] ?? code;
    return "$name ($symbol)";
  }

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? "No email";
    final name = user?.displayName ?? email.split("@")[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileCard(name, email),
                  const SizedBox(height: 16),
                  _buildPreferences(),
                  const SizedBox(height: 16),
                  _buildSupport(),
                  const SizedBox(height: 16),
                  _buildLogoutButton(),
                  const SizedBox(height: 20),
                  const Text(
                    "Voxpense Version 1.0.1",
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header section
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
      color: const Color(0xFF374151),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Settings",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Profile card UI
  Widget _buildProfileCard(String name, String email) {
    return _card(
      Column(
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(email,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildManageProfileButton(),
        ],
      ),
    );
  }

  /// Avatar display with loading and fallback handling
  Widget _buildAvatar() {
    if (isLoadingPhoto) {
      return const CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (isValidImageUrl(imgURL)) {
      return CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(imgURL!),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFA94DFF), Color(0xFF3B82F6)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        getInitials(),
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  /// Navigate to profile management page
  Widget _buildManageProfileButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
          await loadProfilePhoto();
          await FirebaseAuth.instance.currentUser?.reload();
          if (!mounted) return;
          setState(() {});
        },
        style: _buttonStyle(Colors.grey[200]!),
        child: const Text(
          "Manage Profile",
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    );
  }

  /// Preferences section (currency)
  Widget _buildPreferences() {
    final currencyProvider = context.watch<CurrencyProvider>();

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Preferences",
              style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text("Currency",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(
              _getCurrencyDisplay(
                currencyProvider.currencyCode,
                currencyProvider.currencySymbol,
              ),
              style: const TextStyle(fontSize: 10),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CurrencyPage()),
            ),
          ),
        ],
      ),
    );
  }

  /// Support section (help, privacy, terms)
  Widget _buildSupport() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Support",
              style: TextStyle(fontWeight: FontWeight.bold)),
          _navTile("Help Center", Icons.help_outline, const HelpCenterPage()),
          _navTile("Privacy Policy", Icons.privacy_tip_outlined,
              const PrivacyPolicyPage()),
          _navTile("Terms of Service", Icons.description_outlined,
              const TermsOfServicePage()),
        ],
      ),
    );
  }

  /// Navigation tile for settings options
  Widget _navTile(String title, IconData icon, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
    );
  }

  /// Logout button
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: logout,
        icon: const Icon(Icons.logout),
        label: const Text("Logout",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[50],
          foregroundColor: Colors.red,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  /// Reusable card container
  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10)
        ],
      ),
      child: child,
    );
  }
}