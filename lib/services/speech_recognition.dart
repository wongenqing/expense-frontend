import 'package:speech_to_text/speech_to_text.dart';
import 'package:expensetracker_app/services/api_service.dart';
import 'package:flutter/foundation.dart';

// Service class for handling speech recognition
// It listens to user speech, sends final text to backend,
// and returns structured expense data
class SpeechService {
  // Speech-to-text plugin instance
  final SpeechToText _speech = SpeechToText();

  // Internal state flags
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isProcessing = false;

  // Public getter to check if speech engine is currently listening
  bool get isListening => _speech.isListening;

  /// Initialize speech recognition service
  Future<bool> init() async {
    _isInitialized = await _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
    );

    return _isInitialized;
  }

  /// Start listening and send final result to backend
  Future<void> startListening({
    required Function(String text) onText,
    required Function(Map<String, dynamic> result) onResult,
    required Function(String error) onError,
  }) async {
    // Do nothing if not initialized or already listening
    if (!_isInitialized || _isListening) return;

    _isListening = true;

    await _speech.listen(
      onResult: (result) async {
        final text = result.recognizedWords;

        debugPrint("RESULT: $text");

        // Only process final result once
        if (result.finalResult && text.isNotEmpty && !_isProcessing) {
          _isProcessing = true;

          try {
            // Return recognized text to UI first
            onText(text);

            // Send text to backend for NLP processing
            final apiResult = await ApiService.processText(text);

            debugPrint("BACKEND RESULT: $apiResult");

            // Keep only the fields needed by the app
            final safeResult = {
              "amount": apiResult["amount"],
              "category": apiResult["category"] ?? "Others",
              "merchant": apiResult["merchant"] ?? "",
              "date": apiResult["date"],
            };

            // Return processed result back to UI
            onResult(safeResult);
          } catch (e) {
            // Handle common network / processing errors
            if (e.toString().contains("SocketException")) {
              onError("No internet connection");
            } else if (e.toString().contains("TimeoutException")) {
              onError("Server timeout");
            } else {
              onError("Processing failed");
            }
          } finally {
            _isProcessing = false;
          }
        }
      },

      // Speech recognition settings
      listenMode: ListenMode.dictation,
      partialResults: true,
      localeId: "en_US",
      cancelOnError: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  /// Stop listening manually
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }

    _isListening = false;
    debugPrint("Stopped by user");
  }

  /// Handle speech status updates
  void _handleStatus(String status) {
    debugPrint("Speech status: $status");

    // Reset listening state when recognition ends
    if (status == "done" || status == "notListening") {
      _isListening = false;
    }
  }

  /// Handle speech recognition errors
  void _handleError(error) {
    debugPrint("❌ Speech error: $error");
    _isListening = false;
  }
}