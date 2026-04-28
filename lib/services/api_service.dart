import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Service class for communicating with backend API
// Sends user text (voice input) to NLP model and receives structured data
class ApiService {

  // Base URL of your backend server (hosted API)
  static const String baseUrl = "https://web-production-0dbaca.up.railway.app";

  /// Send text to backend and get prediction result
  /// text → raw user input (from speech or manual input)
  static Future<Map<String, dynamic>> processText(String text) async {

    // Build API endpoint URL
    final url = Uri.parse("$baseUrl/predict");

    try {
      // Send POST request with JSON body
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"text": text}),
          )
          // Timeout to prevent hanging request
          .timeout(const Duration(seconds: 10));

      // If request successful
      if (response.statusCode == 200) {

        // Decode JSON response into Map
        return jsonDecode(response.body);

      } else {
        // Log server-side error
        debugPrint("❌ STATUS: ${response.statusCode}");
        debugPrint("❌ BODY: ${response.body}");

        throw Exception("Server error");
      }
    } catch (e) {

      // Log network or timeout errors
      debugPrint("❌ NETWORK ERROR: $e");

      // Rethrow so UI layer can handle it
      rethrow;
    }
  }
}