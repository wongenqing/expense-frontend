import 'dart:io';
import 'dart:convert';
import 'package:expensetracker_app/views/pages/change_password_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Current authenticated user
  final user = FirebaseAuth.instance.currentUser;

  // Controllers for editable fields
  late TextEditingController nameController;
  late TextEditingController emailController;

  // Profile image states
  String? imageUrl;       // Stored image URL from Firestore
  File? selectedImage;    // Local image before upload

  // UI state flags
  bool isLoading = true;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();

    // Initialize text fields with current user data
    nameController = TextEditingController(text: user?.displayName ?? "");
    emailController = TextEditingController(text: user?.email ?? "");

    // Load additional profile data from Firestore
    loadUserProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  /// Displays a floating snackbar for user feedback
  void showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Fetches user profile data from Firestore
  Future<void> loadUserProfile() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();

        // Retrieve profile image URL
        imageUrl = data?['imgURL'];

        // Update name if exists in database
        if (data?['name'] != null && data!['name'].toString().isNotEmpty) {
          nameController.text = data['name'];
        }
      }
    } catch (e) {
      debugPrint("LOAD ERROR: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  /// Allows user to pick an image and upload to Cloudinary
  Future<void> pickAndUploadImage() async {
    try {
      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);

      // Update UI while uploading
      setState(() {
        selectedImage = file;
        isUploading = true;
      });

      final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/dcnzhlglm/image/upload",
      );

      // Prepare multipart request
      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = 'profile_upload'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (!mounted) return;

      final jsonData = jsonDecode(responseData);

      if (jsonData['secure_url'] == null) {
        throw Exception("Upload failed");
      }

      final uploadedImageUrl = jsonData['secure_url'];

      // Save image URL to Firestore
      await FirebaseFirestore.instance.collection("Users").doc(user!.uid).set({
        "imgURL": uploadedImageUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;

      // Reload profile to reflect new image
      await loadUserProfile();

      setState(() {
        imageUrl = uploadedImageUrl;
        selectedImage = null;
        isUploading = false;
      });

      showSnack("Profile photo updated", Colors.green);
    } catch (e) {
      if (!mounted) return;

      setState(() => isUploading = false);
      showSnack("Upload failed", Colors.red);
    }
  }

  /// Handles password change navigation with Google account restriction
  void handleChangePassword() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (!mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    // Detect Google-authenticated users
    bool isGoogle =
        currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    if (isGoogle) {
      showSnack(
        "Password is managed by Google. Please change it in your Google account.",
        Colors.red,
      );
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  /// Saves updated profile information
  Future<void> saveProfile() async {
    try {
      // Update Firebase Auth display name
      await user?.updateDisplayName(nameController.text.trim());

      // Save profile data to Firestore
      await FirebaseFirestore.instance.collection("Users").doc(user!.uid).set({
        "name": nameController.text.trim(),
        "email": user!.email,
      }, SetOptions(merge: true));

      if (!mounted) return;

      showSnack("Profile updated successfully", Colors.green);
    } catch (e) {
      if (!mounted) return;

      showSnack("Error updating profile", Colors.red);
    }
  }

  /// Returns user initials for avatar fallback
  String getInitials() {
    final name = nameController.text.trim();
    if (name.isNotEmpty) return name[0].toUpperCase();

    final email = user?.email;
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }

    return "U";
  }

  /// Validates image URL format
  bool isValidImageUrl(String? url) {
    return url != null &&
        url.isNotEmpty &&
        Uri.tryParse(url)?.hasScheme == true;
  }

  /// Builds profile avatar with multiple states (loading, local, network, fallback)
  Widget buildAvatar() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,

        // Priority: local image → network image → gradient fallback
        image: selectedImage != null
            ? DecorationImage(
                image: FileImage(selectedImage!),
                fit: BoxFit.cover,
              )
            : (!isLoading && isValidImageUrl(imageUrl))
                ? DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,

        gradient:
            (!isLoading && selectedImage == null && !isValidImageUrl(imageUrl))
                ? const LinearGradient(
                    colors: [Color(0xFFA94DFF), Color(0xFF3B82F6)],
                  )
                : null,
      ),
      alignment: Alignment.center,

      // Display loader or initials if needed
      child: (isLoading || isUploading)
          ? const CircularProgressIndicator(strokeWidth: 2)
          : (selectedImage == null && !isValidImageUrl(imageUrl))
              ? Text(
                  getInitials(),
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
    );
  }

  /// Main UI layout (kept unchanged)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      body: Column(
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFA94DFF),
                  Color(0xFF6366F1),
                  Color(0xFF3B82F6),
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Manage Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content section
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                buildCard(
                  child: GestureDetector(
                    onTap: pickAndUploadImage,
                    child: Column(
                      children: [
                        buildAvatar(),
                        const SizedBox(height: 10),
                        const Text(
                          "Change Photo",
                          style: TextStyle(
                            color: Color(0xFFA94DFF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Full Name",
                          style: TextStyle(color: Colors.black45)),
                      TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(border: InputBorder.none),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Email Address",
                          style: TextStyle(color: Colors.black54)),
                      TextField(
                        controller: emailController,
                        enabled: false,
                        decoration:
                            const InputDecoration(border: InputBorder.none),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                buildCard(
                  child: InkWell(
                    onTap: handleChangePassword,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_outline),
                            SizedBox(width: 10),
                            Text("Change Password"),
                          ],
                        ),
                        Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFA94DFF),
                          Color(0xFF6366F1),
                          Color(0xFF3B82F6),
                        ],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reusable card container for consistent UI styling
  Widget buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.06), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }
}