import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

/// Screen that allows users to select and change their preferred currency
class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  // Stores user input for searching currencies
  String searchText = "";

  // List of supported currencies with metadata
  final List<Map<String, String>> currencies = [
    {
      'code': 'MYR',
      'name': 'Malaysian Ringgit',
      'symbol': 'RM',
      'country': '🇲🇾',
    },
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$', 'country': '🇺🇸'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€', 'country': '🇪🇺'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£', 'country': '🇬🇧'},
    {
      'code': 'SGD',
      'name': 'Singapore Dollar',
      'symbol': 'S\$',
      'country': '🇸🇬',
    },
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥', 'country': '🇯🇵'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥', 'country': '🇨🇳'},
    {
      'code': 'AUD',
      'name': 'Australian Dollar',
      'symbol': 'A\$',
      'country': '🇦🇺',
    },
    {
      'code': 'CAD',
      'name': 'Canadian Dollar',
      'symbol': 'C\$',
      'country': '🇨🇦',
    },
    {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'CHF', 'country': '🇨🇭'},
  ];

  @override
  Widget build(BuildContext context) {
    // Access current currency state from provider
    final currencyProvider = context.watch<CurrencyProvider>();
    final selectedCurrency = currencyProvider.currencyCode;

    // Prepare search query for filtering
    final query = searchText.toLowerCase().trim();

    // Filter currencies based on name or code
    final filteredCurrencies = currencies.where((currency) {
      final name = (currency['name'] ?? "").toLowerCase();
      final code = (currency['code'] ?? "").toLowerCase();

      return name.contains(query) || code.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),

      body: Column(
        children: [

          /// Top header with navigation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF14B8A6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Currency",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          /// Main content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                children: [

                  /// Search input field for filtering currencies
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, color: Colors.black12),
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          searchText = value;
                        });
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Colors.grey),
                        hintText: "Search currency...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Scrollable list of currencies
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(blurRadius: 4, color: Colors.black12),
                        ],
                      ),

                      child: ListView.builder(
                        itemCount: filteredCurrencies.length,

                        itemBuilder: (context, index) {
                          final currency = filteredCurrencies[index];
                          final code = currency['code'] ?? "";
                          final isSelected = selectedCurrency == code;

                          return InkWell(
                            onTap: () {
                              // Update selected currency in global state
                              context.read<CurrencyProvider>().setCurrency(
                                    code,
                                    currency['symbol'] ?? "",
                                  );

                              // Return to previous screen
                              Navigator.pop(context);
                            },

                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFECFDF5)
                                    : Colors.white,
                                border: const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFF1F5F9),
                                  ),
                                ),
                              ),

                              child: Row(
                                children: [

                                  /// Country flag emoji
                                  Text(
                                    currency['country'] ?? "🌍",
                                    style: const TextStyle(fontSize: 24),
                                  ),

                                  const SizedBox(width: 12),

                                  /// Currency name and code
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currency['name'] ?? "",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          "$code • ${currency['symbol'] ?? ""}",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  /// Indicator for selected currency
                                  if (isSelected)
                                    const Icon(
                                      Icons.check,
                                      color: Color(0xFF16A34A),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
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