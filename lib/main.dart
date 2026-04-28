import 'package:expensetracker_app/services/auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';
import 'package:flutter/services.dart';
import 'views/pages/voice_input_page.dart';

/// This navigator key lets the app move between pages
/// even without using BuildContext (useful for widget-triggered navigation)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Make sure Flutter is fully initialized before running async code
  WidgetsFlutterBinding.ensureInitialized();

  // Set up Firebase for the app
  await Firebase.initializeApp();

  // Load the user's preferred currency before the app starts
  final currencyProvider = CurrencyProvider();
  await currencyProvider.loadCurrency();

  // Start the app and provide currency state globally
  runApp(
    ChangeNotifierProvider.value(
      value: currencyProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Used to communicate with the native Android widget
  static const platform = MethodChannel('widget_channel');

  /// By default, the app opens the authentication wrapper
  Widget _defaultHome = const AuthWrapper();

  @override
  void initState() {
    super.initState();

    // Check if the app was opened from the home screen widget
    checkWidgetLaunch();

    // Listen for widget clicks when the app is already running
    platform.setMethodCallHandler((call) async {
      if (call.method == "onWidgetClicked") {
        // Navigate straight to the voice input screen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const VoiceInputPage(fromWidget: true),
          ),
        );
      }
    });
  }

  /// This function checks whether the app was launched from the widget
  Future<void> checkWidgetLaunch() async {
    try {
      // Ask the native side if the widget triggered this launch
      final bool openVoice =
          await platform.invokeMethod('getLaunchAction');

      // If yes, show the voice input page immediately
      if (openVoice) {
        setState(() {
          _defaultHome = const VoiceInputPage(fromWidget: true);
        });
      }
    } catch (e) {
      // Print error if something goes wrong
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Allows navigation without needing context
      navigatorKey: navigatorKey,

      // Decide which page to show first
      home: _defaultHome,
    );
  }
}