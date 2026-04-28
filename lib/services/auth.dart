import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

// Service class for handling Google authentication
// Handles:
// - Google login
// - saving user data into Firestore
// - sign out
// - getting current user
class GoogleSignInService {

  // Firebase authentication instance
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Firestore instance
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Google Sign-In instance
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Flag to ensure GoogleSignIn is initialized only once
  static bool _initialized = false;

  /// Initialize Google Sign-In (only runs once)
  static Future<void> _initGoogle() async {
    if (_initialized) return;

    await _googleSignIn.initialize(
      serverClientId:
          '879638233587-u17qn2j80262gne7cs2emvv4jc16kk74.apps.googleusercontent.com',
    );

    _initialized = true;
  }

  /// Sign in using Google account
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Ensure GoogleSignIn is initialized
      await _initGoogle();

      // Open Google account picker
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      // Get authentication tokens (ID token)
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      // Create Firebase credential using Google ID token
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase using the credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User user = userCredential.user!;

      // Save or update user profile in Firestore
      await _firestore.collection('Users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'profile_image': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge ensures no overwrite of existing data

      return userCredential;
    } catch (e) {
      // Log error for debugging
      debugPrint('Google Sign-In Error: $e');

      // Rethrow error so UI can handle it
      rethrow;
    }
  }

  /// Sign out from both Google and Firebase
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Get current logged-in Firebase user
  static User? getCurrentUser() => _auth.currentUser;
}