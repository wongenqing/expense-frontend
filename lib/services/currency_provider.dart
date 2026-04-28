import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider class to manage currency settings and conversion
// Handles:
// - current selected currency
// - saving/loading user preference
// - converting amounts between currencies
class CurrencyProvider with ChangeNotifier {

  // Current selected currency code (e.g., MYR, USD)
  String _currencyCode = "RM";

  // Currency symbol used for display (e.g., RM, $, €)
  String _currencySymbol = "RM";

  // Exchange rates relative to MYR (base currency)
  final Map<String, double> exchangeRates = {
    "MYR": 1.0,
    "USD": 0.21,
    "EUR": 0.19,
    "GBP": 0.16,
    "SGD": 0.29,
    "JPY": 30.0,
    "CNY": 1.5,
    "AUD": 0.32,
    "CAD": 0.28,
    "CHF": 0.19,
  };

  // Getter for currency code
  String get currencyCode => _currencyCode;

  // Getter for currency symbol
  String get currencySymbol => _currencySymbol;

  /// Load saved currency from local storage (SharedPreferences)
  /// This runs when the app starts to restore user preference
  Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved values, fallback to default "RM"
    _currencyCode = prefs.getString('currencyCode') ?? "RM";
    _currencySymbol = prefs.getString('currencySymbol') ?? "RM";

    // Notify UI to update with loaded currency
    notifyListeners();
  }

  /// Update currency and save to local storage
  /// code → currency code (e.g., USD)
  /// symbol → currency symbol (e.g., $)
  Future<void> setCurrency(String code, String symbol) async {
    _currencyCode = code;
    _currencySymbol = symbol;

    final prefs = await SharedPreferences.getInstance();

    // Save user selection
    await prefs.setString('currencyCode', code);
    await prefs.setString('currencySymbol', symbol);

    // Notify UI to refresh
    notifyListeners();
  }

  /// Convert stored MYR amount to selected currency
  double convert(double amountInRM) {
    double rate = exchangeRates[_currencyCode] ?? 1.0;
    return amountInRM * rate;
  }

  /// Convert user input amount back to MYR (base currency)
  /// Used when saving expenses so database always stores MYR
  double convertToBase(double amount) {
    double rate = exchangeRates[_currencyCode] ?? 1.0;

    // Safety check to avoid division by zero
    if (rate == 0) return amount;

    return amount / rate;
  }
}