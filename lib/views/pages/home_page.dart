import 'package:expensetracker_app/views/pages/settings_page.dart';
import 'package:expensetracker_app/views/widgets/navbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

// Home dashboard page
// Shows overall expense summary, top categories, and recent transactions
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Current logged-in user ID
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  // Cache category data to avoid repeated Firestore reads
  Map<String, Map<String, dynamic>> categoryCache = {};

  /// Get expense records from Firestore for the current user
  Stream<QuerySnapshot> getExpensesStream() {
    return FirebaseFirestore.instance
        .collection("Expenses")
        .where("uid", isEqualTo: uid)
        .orderBy("expense_date", descending: true)
        .snapshots();
  }

  /// Get category details using category_id
  /// First check cache, then fetch from Firestore if needed
  Future<Map<String, dynamic>?> getCategory(String categoryId) async {
    if (categoryCache.containsKey(categoryId)) {
      return categoryCache[categoryId];
    }

    final doc = await FirebaseFirestore.instance
        .collection("Categories")
        .doc(categoryId)
        .get();

    if (doc.exists) {
      categoryCache[categoryId] = doc.data()!;
      return doc.data();
    }

    return null;
  }

  /// Convert HEX color string into a Flutter Color
  Color hexToColor(String hex) {
    hex = hex.replaceAll("#", "");

    if (hex.length == 6) {
      hex = "FF$hex";
    }

    return Color(int.parse(hex, radix: 16));
  }

  /// Calculate expense totals for today, this week, this month, and this year
  Map<String, double> calculateTotals(
    List<QueryDocumentSnapshot> docs,
    CurrencyProvider currency,
  ) {
    double today = 0;
    double week = 0;
    double month = 0;
    double year = 0;

    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);
    DateTime startOfWeek = todayStart.subtract(Duration(days: now.weekday - 1));
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime startOfYear = DateTime(now.year, 1, 1);

    for (var doc in docs) {
      // Convert stored base amount into selected display currency
      double amountRM = (doc['amount'] as num).toDouble();
      double amount = currency.convert(amountRM);

      DateTime date = (doc['expense_date'] as Timestamp).toDate();
      DateTime dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == todayStart) {
        today += amount;
      }

      if (dateOnly.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
        week += amount;
      }

      if (!dateOnly.isBefore(startOfMonth)) {
        month += amount;
      }

      if (!dateOnly.isBefore(startOfYear)) {
        year += amount;
      }
    }

    return {"total": year, "today": today, "week": week, "month": month};
  }

  /// Build a summary of spending by category for the current year
  Future<List<Map<String, dynamic>>> buildCategorySummary(
    List<QueryDocumentSnapshot> docs,
    CurrencyProvider currency,
  ) async {
    Map<String, double> categoryTotals = {};

    DateTime now = DateTime.now();
    DateTime startOfYear = DateTime(now.year, 1, 1);

    for (var doc in docs) {
      DateTime date = (doc["expense_date"] as Timestamp).toDate();

      // Ignore records before this year
      if (date.isBefore(startOfYear)) continue;

      String categoryId = doc["category_id"];
      double amountRM = (doc["amount"] as num).toDouble();
      double amount = currency.convert(amountRM);

      categoryTotals[categoryId] = (categoryTotals[categoryId] ?? 0) + amount;
    }

    List<Map<String, dynamic>> result = [];

    // Replace category IDs with readable category info
    for (var entry in categoryTotals.entries) {
      final category = await getCategory(entry.key);

      result.add({
        "name": category?["category_name"] ?? "Unknown",
        "icon": category?["icon"] ?? "❓",
        "amount": entry.value,
        "color": category?["color"] ?? "#6B7280",
      });
    }

    // Sort highest amount first
    result.sort((a, b) => b["amount"].compareTo(a["amount"]));

    return result;
  }

  /// Top header section of the home page
  Widget buildHeader(Map<String, double> totals, CurrencyProvider currency) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total expense and settings button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total Expenses",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    "${currency.currencySymbol} ${totals["total"]!.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Year ${DateFormat("yyyy").format(DateTime.now())}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),

              // Open settings page
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
                child: buildCircleButton(Icons.settings_outlined),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Summary cards row
          Row(
            children: [
              buildStatCard("Today", totals["today"]!, currency),
              buildStatCard("This Week", totals["week"]!, currency),
              buildStatCard("This Month", totals["month"]!, currency),
            ],
          ),
        ],
      ),
    );
  }

  /// Top spending categories list
  Widget buildTopSpending(
    List<Map<String, dynamic>> categorySummary,
    CurrencyProvider currency,
  ) {
    if (categorySummary.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            "No spending records",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    double total = 0;
    for (var c in categorySummary) {
      total += c["amount"];
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categorySummary.length,
      itemBuilder: (context, index) {
        final category = categorySummary[index];
        final percentage = total == 0 ? 0 : (category["amount"] / total) * 100;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Category row
              Row(
                children: [
                  Text(category["icon"], style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category["name"],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "${percentage.toInt()}% of total",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    "${currency.currencySymbol} ${category["amount"].toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress bar showing spending proportion
              LinearProgressIndicator(
                borderRadius: BorderRadius.circular(10),
                value: percentage / 100,
                color: hexToColor(category["color"]),
                backgroundColor: Colors.grey[300],
                minHeight: 8,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Recent transactions section
  Widget buildRecentTransactions(
    List<QueryDocumentSnapshot> docs,
    CurrencyProvider currency,
  ) {
    // Only show the latest 5 records
    final recentDocs = docs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),

        // Section header
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Recent Transactions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),

            // Jump to transactions tab
            TextButton(
              onPressed: () {
                NavbarWidget.switchTab(context, 1);
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                "View All",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        if (recentDocs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                "No recent transactions",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentDocs.length,
            itemBuilder: (context, index) {
              final doc = recentDocs[index];

              final amountRM = (doc["amount"] as num).toDouble();
              final convertedAmount = currency.convert(amountRM);
              final date = (doc["expense_date"] as Timestamp).toDate();
              final categoryId = doc["category_id"];

              return FutureBuilder(
                future: getCategory(categoryId),
                builder: (context, snapshot) {
                  String name = "Unknown";
                  String emoji = "❓";
                  String colorHex = "#6B7280";

                  if (snapshot.hasData && snapshot.data != null) {
                    final category = snapshot.data!;
                    name = category["category_name"] ?? "Unknown";
                    emoji = category["icon"] ?? "❓";
                    colorHex = category["color"] ?? "#6B7280";
                  }

                  final color = hexToColor(colorHex);
                  final data = doc.data() as Map<String, dynamic>;

                  final merchant = (data['merchant'] ?? '').toString().trim();

                  // Use merchant name if available, otherwise fallback to category name
                  String displayTitle = merchant.isNotEmpty ? merchant : name;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Category icon avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Transaction title and date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat("MMM dd, yyyy").format(date),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Transaction amount
                        Text(
                          "- ${currency.currencySymbol} ${convertedAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  /// Main UI
  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
              ),
            ),
          ),

          // Foreground content
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: getExpensesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final docs = snapshot.data!.docs;

                final totals = calculateTotals(
                  docs.cast<QueryDocumentSnapshot>(),
                  currency,
                );

                return Column(
                  children: [
                    buildHeader(totals, currency),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(25),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: FutureBuilder(
                          future: buildCategorySummary(docs, currency),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final categorySummary = snapshot.data!;

                            return ListView(
                              children: [
                                // Top categories section header
                                Row(
                                  children: [
                                    const Text(
                                      "Top Categories",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        NavbarWidget.switchTab(context, 2);
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        "View All",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                buildTopSpending(categorySummary, currency),

                                buildRecentTransactions(
                                  docs.cast<QueryDocumentSnapshot>(),
                                  currency,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// settings button
  Widget buildCircleButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  /// stat card to display totals of today, this week, this month
  Widget buildStatCard(String title, double amount, CurrencyProvider currency) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),

            const SizedBox(height: 5),

            Text(
              currency.currencySymbol,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              amount.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
