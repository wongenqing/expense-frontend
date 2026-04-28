import 'package:cloud_firestore/cloud_firestore.dart';

// Service class for handling Firestore database operations
// Used to store user data and expense records
class DatabaseMethods {

  /// Add a new user into the "Users" collection
  /// userId → document ID (same as Firebase Auth UID)
  /// userInfoMap → contains user details like name, email, etc.
  Future addUser(String userId, Map<String, dynamic> userInfoMap) {
    return FirebaseFirestore.instance
        .collection("Users")
        .doc(userId)
        .set(userInfoMap);
  }

  /// Add a new expense into the "Expenses" collection
  /// expenseId → unique document ID for the expense
  /// expenseInfoMap → contains amount, category, date, etc.
  Future addExpense(String expenseId, Map<String, dynamic> expenseInfoMap) {
    return FirebaseFirestore.instance
        .collection("Expenses")
        .doc(expenseId)
        .set(expenseInfoMap);
  }
}