import 'package:expensetracker_app/services/speech_recognition.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';
import 'package:intl/intl.dart';

// This page handles voice input for expenses
// It works both from normal app flow and home screen widget
class VoiceInputPage extends StatefulWidget {
  final bool fromWidget; // true if opened from widget

  const VoiceInputPage({super.key, this.fromWidget = false});

  @override
  State<VoiceInputPage> createState() => _VoiceInputPageState();
}

class _VoiceInputPageState extends State<VoiceInputPage>
    with SingleTickerProviderStateMixin {
  bool isRecording = false; // whether mic is recording

  late AnimationController _pulseController; // mic animation

  final SpeechService _speechService = SpeechService(); // speech service

  String recognizedText = ""; // live speech text
  bool isProcessing = false; // AI parsing status

  bool isFromWidget = false; // local copy of widget flag
  bool _alreadyProcessed = false; // avoid duplicate results

  Map<String, dynamic>? parsedResult; // AI result

  @override
  void initState() {
    super.initState();

    // check how this page was opened
    isFromWidget = widget.fromWidget;

    // setup mic animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.9,
      upperBound: 1.1,
    );

    _pulseController.repeat(reverse: true);

    // init speech and auto start if from widget
    _initSpeech().then((_) {
      if (isFromWidget) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) startRecording();
        });
      }
    });
  }

  // initialize speech recognition
  Future<void> _initSpeech() async {
    final success = await _speechService.init();

    if (!success) {
      debugPrint("Speech init failed");

      // only show UI error if user opened manually
      if (mounted && !isFromWidget) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Microphone permission required"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // clean up everything when leaving page
    _pulseController.dispose();
    _speechService.stopListening();
    super.dispose();
  }

  // ===== FIRESTORE PART =====

  // find category id from database (flexible matching)
  Future<String?> getCategoryId(String categoryName) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection("Categories")
          .get();

      for (var doc in query.docs) {
        final dbName = doc['category_name'].toString().toLowerCase().trim();
        final inputName = categoryName.toLowerCase().trim();

        // try different matching styles
        if (dbName == inputName ||
            inputName.contains(dbName) ||
            dbName.contains(inputName)) {
          return doc['category_id'];
        }
      }
    } catch (e) {
      debugPrint("Error getting category: $e");
    }
    return null;
  }

  // save expense into firestore
  Future<void> saveExpense() async {
    if (parsedResult == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // get values from AI
      final amount = parsedResult?['amount'];
      final categoryName = parsedResult?['category'];
      final merchant = parsedResult?['merchant'];
      final dateStr = parsedResult?['date'];

      if (amount == null) {
        throw Exception("Amount is missing");
      }

      // convert currency to base (RM)
      final currency = Provider.of<CurrencyProvider>(context, listen: false);
      double amountInRM = currency.convertToBase(amount);

      // handle date
      DateTime expenseDate = DateTime.now();

      if (dateStr != null && dateStr.trim().isNotEmpty) {
        final lower = dateStr.toLowerCase().trim();

        if (lower.contains("yesterday")) {
          expenseDate = DateTime.now().subtract(const Duration(days: 1));
        } else if (lower.contains("today")) {
          expenseDate = DateTime.now();
        } else if (lower.contains("tomorrow")) {
          expenseDate = DateTime.now().add(const Duration(days: 1));
        } else if (dateStr.contains("UTC")) {
          try {
            final cleaned = dateStr
                .replaceAll(RegExp(r'\s*at\s*'), ' ')
                .replaceAll(RegExp(r'UTC[+-]\d+'), '')
                .trim();

            expenseDate = DateFormat("MMMM d, yyyy hh:mm:ss a").parse(cleaned);
          } catch (e) {
            debugPrint("Date parse failed: $e");
          }
        }
      }

      // get category id
      String? categoryId = await getCategoryId(categoryName ?? "");

      if (categoryId == null) {
        throw Exception("Category not found");
      }

      // create new document
      final docRef = FirebaseFirestore.instance.collection("Expenses").doc();

      await docRef.set({
        "expense_id": docRef.id,
        "amount": amountInRM,
        "original_amount": amount,
        "original_currency": currency.currencyCode,
        "category_id": categoryId,
        "createdAt": FieldValue.serverTimestamp(),
        "description": recognizedText,
        "expense_date": Timestamp.fromDate(expenseDate),
        "merchant": merchant ?? "",
        "uid": user.uid,
      });

      if (!mounted) return;

      // success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Expense added successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // auto close if from widget
      if (isFromWidget) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Save error: $e");

      if (!mounted) return;

      // show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===== VOICE PART =====

  // start recording
  Future<void> startRecording() async {
    if (isRecording) return;
    if (!mounted) return;

    setState(() {
      isRecording = true;
      recognizedText = "";
      parsedResult = null;
      _alreadyProcessed = false;
    });

    await _speechService.startListening(
      // live speech text
      onText: (text) {
        if (!mounted) return;
        setState(() {
          recognizedText = text;
          isProcessing = true;
        });
      },

      // final AI result
      onResult: (result) async {
        if (!mounted || _alreadyProcessed) return;

        _alreadyProcessed = true;

        setState(() {
          parsedResult = result;
          isProcessing = false;
        });

        // auto confirm if from widget
        if (isFromWidget) {
          await Future.delayed(const Duration(milliseconds: 300));
          await confirmRecording();
        }
      },

      // error
      onError: (error) {
        if (!mounted) return;
        setState(() {
          isProcessing = false;
        });
        debugPrint(error);
      },
    );
  }

  // cancel recording
  Future<void> cancelRecording() async {
    await _speechService.stopListening();
    if (!mounted) return;

    setState(() {
      isRecording = false;
      recognizedText = "";
      parsedResult = null;
      isProcessing = false;
    });
  }

  // confirm and save
  Future<void> confirmRecording() async {
    await _speechService.stopListening();
    if (!mounted) return;

    setState(() {
      isRecording = false;
      isProcessing = false;
    });

    await saveExpense();
  }

  // format date for display
  String _formatDateOnly(String? dateStr) {
    if (dateStr == null) return "-";

    final lower = dateStr.toLowerCase().trim();
    DateTime date = DateTime.now();

    if (lower.contains("yesterday")) {
      date = DateTime.now().subtract(const Duration(days: 1));
    } else if (lower.contains("today")) {
      date = DateTime.now();
    } else if (lower.contains("tomorrow")) {
      date = DateTime.now().add(const Duration(days: 1));
    } else if (dateStr.contains("UTC")) {
      try {
        final cleaned = dateStr
            .replaceAll(RegExp(r'\s*at\s*'), ' ')
            .replaceAll(RegExp(r'UTC[+-]\d+'), '')
            .trim();

        date = DateFormat("MMMM d, yyyy hh:mm:ss a").parse(cleaned);
      } catch (_) {}
    }

    return "${date.day}/${date.month}/${date.year}";
  }

  // ===== UI PART =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        // main padding for safe spacing from top and sides
        padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
        decoration: const BoxDecoration(
          // background gradient for the whole page
          gradient: LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFEF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // ===== TOP BAR =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // close button to exit page
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                // page title
                const Text(
                  "Voice Input",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // spacer to balance layout
                const SizedBox(width: 50),
              ],
            ),

            // ===== MAIN CONTENT =====
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 100),

                    // mic animation (pulsing when recording)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: isRecording ? _pulseController.value : 1,
                          child: buildMic(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // switch UI based on recording state
                    isRecording ? buildListeningUI() : buildIdleUI(),
                  ],
                ),
              ),
            ),

            // ===== BOTTOM BUTTONS =====
            Column(
              children: [
                // show start button when not recording
                if (!isRecording)
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      onPressed: startRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.pink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Start Recording",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // show cancel + confirm buttons when recording
                if (isRecording)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // cancel recording
                      SizedBox(
                        width: 140,
                        child: ElevatedButton(
                          onPressed: cancelRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // confirm and save expense
                      SizedBox(
                        width: 140,
                        child: ElevatedButton(
                          onPressed: confirmRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "Confirm",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildListeningUI() {
    return Column(
      children: [
        // status text when recording
        const Text(
          "Listening...",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        // ===== LIVE TRANSCRIPT =====
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text(
                "Recognized:",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),

              // show live speech text
              Text(
                recognizedText.isEmpty ? "Speak now..." : '"$recognizedText"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // ===== AI LOADING INDICATOR =====
        if (isProcessing)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10),
              Text("AI is parsing...", style: TextStyle(color: Colors.white)),
            ],
          ),

        // show parsed result after AI processing
        if (parsedResult != null) buildResultUI(),
      ],
    );
  }

  // format number to 2 decimal places
  String formatAmount(dynamic value) {
    if (value == null) return "-";
    return double.parse(value.toString()).toStringAsFixed(2);
  }

  Widget buildResultUI() {
    final currency = Provider.of<CurrencyProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // result title
          const Text(
            "🧠 AI Result",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          // amount with currency symbol
          buildRow(
            "💰 Amount",
            parsedResult?['amount'] != null
                ? "${currency.currencySymbol} ${formatAmount(parsedResult?['amount'])}"
                : "-",
          ),

          // other extracted fields
          buildRow("📅 Date", _formatDateOnly(parsedResult?['date'])),
          buildRow("🏪 Merchant", parsedResult?['merchant']),
          buildRow("🏷 Category", parsedResult?['category']),
        ],
      ),
    );
  }

  // reusable row for label + value
  Widget buildRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.toString().trim().isEmpty)
                  ? "-"
                  : value.toString(),
              textAlign: TextAlign.right,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // idle screen before recording starts
  Widget buildIdleUI() {
    return Column(
      children: const [
        Text(
          "Tap to Record",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "Say your expense naturally",
          style: TextStyle(color: Colors.white70),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  // mic UI with layered circles
  Widget buildMic() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_none_sharp,
                size: 40,
                color: Color(0xFFEC4899),
              ),
            ),
          ),
        ),
      ),
    );
  }
}