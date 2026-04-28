import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

/// Model to store category analytics data
class CategoryData {
  final String name; // Category name
  final double amount; // Total spending
  final Color color; // Display color
  final int transactionCount; // Number of transactions
  final String icon; // Emoji/icon

  CategoryData({
    required this.name,
    required this.amount,
    required this.color,
    required this.transactionCount,
    required this.icon,
  });
}

// Analytics page to visualize spending patterns
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  // Current user ID
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // Selected filter period
  String selectedPeriod = "All";

  // Custom date range
  DateTime? customStartDate;
  DateTime? customEndDate;

  /// Convert HEX string to Flutter Color
  Color hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse("0x$hex"));
  }

  /// Get date range based on selected filter
  DateTimeRange getDateRange() {
    final now = DateTime.now();

    switch (selectedPeriod) {
      case "Today":
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

      case "This Week":
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: now,
        );

      case "This Month":
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);

      case "This Year":
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);

      case "Custom":
        return DateTimeRange(
          start: customStartDate ?? DateTime(2000),
          end: customEndDate ?? now,
        );

      default:
        return DateTimeRange(start: DateTime(2000), end: now);
    }
  }

  /// Period selection button (Today, Week, Month, etc.)
  Widget periodButton(String label) {
    bool isSelected = selectedPeriod == label;

    return GestureDetector(
      onTap: () async {
        // Handle custom date picker
        if (label == "Custom") {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
            initialDateRange: customStartDate != null && customEndDate != null
                ? DateTimeRange(start: customStartDate!, end: customEndDate!)
                : null,
          );

          if (picked != null) {
            setState(() {
              selectedPeriod = "Custom";
              customStartDate = picked.start;
              customEndDate = picked.end;
            });
          }
        } else {
          // Normal preset period
          setState(() {
            selectedPeriod = label;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Reusable white card container
  Widget whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get currency provider
    final currency = Provider.of<CurrencyProvider>(context);

    // Get selected date range
    final range = getDateRange();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          /// HEADER UI
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 55, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF14B8A6)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Analytics",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Track your spending patterns",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          /// MAIN DATA STREAM (EXPENSES)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("Expenses")
                  .where("uid", isEqualTo: uid)
                  .where(
                    "expense_date",
                    isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
                  )
                  .where(
                    "expense_date",
                    isLessThan: Timestamp.fromDate(range.end),
                  )
                  .orderBy("expense_date", descending: true)
                  .snapshots(),

              builder: (context, expenseSnapshot) {
                if (!expenseSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = expenseSnapshot.data!.docs;

                /// LOAD CATEGORY DATA
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("Categories")
                      .get(),

                  builder: (context, categorySnapshot) {
                    if (!categorySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    /// Build category lookup map
                    Map<String, Map<String, dynamic>> categoryMap = {};
                    for (var doc in categorySnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;

                      categoryMap[doc.id] = {
                        "name": data["category_name"] ?? "Unknown",
                        "color": data["color"] ?? "#999999",
                        "icon": data["icon"] ?? "📦",
                      };
                    }

                    /// PROCESS EXPENSE DATA
                    Map<String, double> categoryTotals = {};
                    Map<String, int> categoryCounts = {};
                    double totalExpense = 0;

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;

                      String categoryId = data["category_id"] ?? "";
                      double amount = (data["amount"] ?? 0).toDouble();

                      // Sum total per category
                      categoryTotals[categoryId] =
                          (categoryTotals[categoryId] ?? 0) + amount;

                      // Count transactions per category
                      categoryCounts[categoryId] =
                          (categoryCounts[categoryId] ?? 0) + 1;

                      totalExpense += amount;
                    }

                    /// Convert into chart-friendly data
                    List<CategoryData> chartData = [];

                    categoryTotals.forEach((categoryId, amount) {
                      final category = categoryMap[categoryId];

                      chartData.add(
                        CategoryData(
                          name: category?["name"] ?? "Unknown",
                          amount: amount,
                          color: hexToColor(category?["color"] ?? "#999999"),
                          transactionCount: categoryCounts[categoryId] ?? 0,
                          icon: category?["icon"] ?? "📦",
                        ),
                      );
                    });

                    // Sort by highest spending
                    chartData.sort((a, b) => b.amount.compareTo(a.amount));

                    /// UI DISPLAY
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            /// PERIOD SELECTOR
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  periodButton("All"),
                                  const SizedBox(width: 8),
                                  periodButton("Today"),
                                  const SizedBox(width: 8),
                                  periodButton("This Week"),
                                  const SizedBox(width: 8),
                                  periodButton("This Month"),
                                  const SizedBox(width: 8),
                                  periodButton("Custom"),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// DOUGHNUT CHART
                            whiteCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Spending by Category"),

                                  const SizedBox(height: 20),

                                  SizedBox(
                                    height: 230,
                                    child: chartData.isEmpty
                                        ? const Center(
                                            child: Text("No records found"),
                                          )
                                        : Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SfCircularChart(
                                                margin: EdgeInsets.zero,
                                                series: <CircularSeries>[
                                                  DoughnutSeries<
                                                    CategoryData,
                                                    String
                                                  >(
                                                    dataSource: chartData,
                                                    xValueMapper: (data, _) =>
                                                        data.name,
                                                    yValueMapper: (data, _) =>
                                                        currency.convert(
                                                          data.amount,
                                                        ),
                                                    pointColorMapper:
                                                        (data, _) => data.color,
                                                    innerRadius: '70%',
                                                  ),
                                                ],
                                              ),

                                              /// CENTER TOTAL TEXT
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    "${currency.currencySymbol} ${currency.convert(totalExpense).toStringAsFixed(2)}",
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const Text("Total"),
                                                ],
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// CATEGORY BREAKDOWN LIST
                            if (chartData.isNotEmpty)
                              whiteCard(
                                child: Column(
                                  children: chartData.map((data) {
                                    double percentage = totalExpense == 0
                                        ? 0
                                        : data.amount / totalExpense;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),

                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Row(
                                            children: [
                                              // Category icon
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: data.color.withValues(
                                                    alpha: 0.20,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(data.icon),
                                                ),
                                              ),

                                              const SizedBox(width: 10),

                                              // Category name + percentage
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      data.name,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    Text(
                                                      "${(percentage * 100).toStringAsFixed(1)}% of total",
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Amount + transaction count
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    "${currency.currencySymbol} ${currency.convert(data.amount).toStringAsFixed(2)}",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    "${data.transactionCount} transactions",
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 6),

                                          // Progress bar
                                          LinearProgressIndicator(
                                            value: percentage,
                                            minHeight: 8,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation(
                                              data.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
