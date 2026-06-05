import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:expensetracker_app/views/pages/set_budget_page.dart';
import 'package:expensetracker_app/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  StreamSubscription? _budgetSub;
  StreamSubscription? _expenseSub;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> budgetsCache = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> expensesCache = [];

  bool _isProcessingAlerts = false;
  bool _hasRunInitialAlertCheck = false;
  double _lastKnownExpenseTotal = -1;

  @override
  void initState() {
    super.initState();

    // Handle cold start: app was launched by tapping a notification
    // No need to navigate (we're already here), just skip the alert re-fire
    if (NotificationService.launchedFromNotification) {
      _hasRunInitialAlertCheck = true; // block alert re-fire
      NotificationService.launchedFromNotification = false; // reset flag
    }

    _budgetSub = _budgetStream().listen((budgetSnap) {
      budgetsCache = budgetSnap.docs;
      _tryRunAlerts();
    });

    _expenseSub = _expenseStream().listen((expenseSnap) {
      expensesCache = expenseSnap.docs;
      final newTotal = expensesCache.fold<double>(
        0,
        (sum, doc) => sum + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
      );
      if (_lastKnownExpenseTotal != newTotal) {
        _lastKnownExpenseTotal = newTotal;
        _tryRunAlerts(forceRun: true);
      } else {
        _tryRunAlerts();
      }
    });
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFF3F4F6);
    }
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _budgetStream() {
    return FirebaseFirestore.instance
        .collection('Budgets')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _expenseStream() {
    return FirebaseFirestore.instance
        .collection('Expenses')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Categories')
        .get();

    final categories = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': data['category_name'] ?? data['name'] ?? 'Unnamed Category',
        'icon': data['icon'] ?? '📌',
        'color': data['color'] ?? '#F3F4F6',
      };
    }).toList();

    categories.sort(
      (a, b) => a['name'].toString().toLowerCase().compareTo(
        b['name'].toString().toLowerCase(),
      ),
    );

    return categories;
  }

  double _calculateMonthlySpent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
    String categoryId,
    String categoryName,
  ) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

    double total = 0;

    for (final doc in expenses) {
      final data = doc.data();

      final expenseCategoryId = data['category_id']?.toString();
      final expenseCategoryName = data['category_name']?.toString();

      final sameCategory =
          expenseCategoryId == categoryId ||
          expenseCategoryName == categoryName;

      if (!sameCategory) continue;

      final dateValue = data['expense_date'];
      DateTime? expenseDate;

      if (dateValue is Timestamp) {
        expenseDate = dateValue.toDate();
      } else if (dateValue is DateTime) {
        expenseDate = dateValue;
      }

      if (expenseDate == null) continue;

      final isCurrentMonth =
          expenseDate.isAtSameMomentAs(startOfMonth) ||
          (expenseDate.isAfter(startOfMonth) &&
              expenseDate.isBefore(startOfNextMonth));

      if (!isCurrentMonth) continue;

      total += (data['amount'] as num?)?.toDouble() ?? 0;
    }

    return total;
  }

  Future<void> _checkBudgetAlerts({
    required Map<String, dynamic> budget,
    required double spent,
    required String budgetId,
  }) async {
    final budgetRef = FirebaseFirestore.instance
        .collection('Budgets')
        .doc(budgetId);

    final snapshot = await budgetRef.get();
    final data = snapshot.data();
    if (data == null) return;

    final categoryName = budget['category_name']?.toString() ?? 'Budget';
    final budgetAmount = (budget['budget_amount'] as num?)?.toDouble() ?? 0;
    final alertPercentage =
        (budget['alert_percentage'] as num?)?.toDouble() ?? 80;

    if (budgetAmount <= 0) return;

    final usedPercent = (spent / budgetAmount) * 100;

    // Determine current state purely from current spent
    String newState;
    if (usedPercent >= 100) {
      newState = "over_limit";
    } else if (usedPercent >= alertPercentage) {
      newState = "near_limit";
    } else {
      newState = "on_track";
    }

    final oldState = data['budgetState'] ?? "on_track";
    final lastAlertedSpent =
        (data['lastAlertedSpent'] as num?)?.toDouble() ?? -1;

    // Determine if should alert based on 3 conditions:

    // Condition 1: State changed (e.g. on_track → near_limit, near_limit → over_limit)
    final isStateChange = newState != oldState;

    // Condition 2: Same alertable state but spent increased (new/updated expense added)
    final isSpentIncreased =
        newState == oldState &&
        (newState == "near_limit" || newState == "over_limit") &&
        spent > lastAlertedSpent;

    // Condition 3: Spent decreased but still in an alertable state
    // e.g. was 45 (near_limit), edited to 30 (still near_limit) → re-alert
    final isSpentDecreased =
        newState == oldState &&
        (newState == "near_limit" || newState == "over_limit") &&
        spent < lastAlertedSpent;

    final shouldAlert = isStateChange || isSpentIncreased || isSpentDecreased;

    // No alert needed if on_track (regardless of change)
    if (newState == "on_track") {
      // Only update state silently if it changed (e.g. was near_limit, now on_track)
      if (isStateChange) {
        await budgetRef.update({
          'budgetState': newState,
          'lastAlertedSpent': spent,
          'lastAlertAt': FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    if (!shouldAlert) return;

    // Fire the correct notification
    if (newState == "near_limit") {
      await NotificationService.showBudgetAlert(
        title: 'Budget Alert',
        body:
            'Your $categoryName spending is near the limit '
            '(${usedPercent.toStringAsFixed(0)}% used).',
      );
    } else if (newState == "over_limit") {
      await NotificationService.showBudgetAlert(
        title: 'Over Budget',
        body:
            'You exceeded your $categoryName budget '
            '(${usedPercent.toStringAsFixed(0)}% used).',
      );
    }

    // Save latest state and spent amount
    await budgetRef.update({
      'budgetState': newState,
      'lastAlertedSpent': spent,
      'lastAlertAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _tryRunAlerts({bool forceRun = false}) async {
    if (_isProcessingAlerts) return;
    if (budgetsCache.isEmpty || expensesCache.isEmpty) return;

    // NEW: Block re-running on cold launch / app resume unless expenses changed
    if (!forceRun && _hasRunInitialAlertCheck) return;

    _isProcessingAlerts = true;
    _hasRunInitialAlertCheck = true; // Mark as done for this session

    for (final budgetDoc in budgetsCache) {
      final budget = budgetDoc.data();
      final categoryId = budget['category_id']?.toString() ?? '';
      final categoryName = budget['category_name']?.toString() ?? '';
      final spent = _calculateMonthlySpent(
        expensesCache,
        categoryId,
        categoryName,
      );

      await _checkBudgetAlerts(
        budget: budget,
        spent: spent,
        budgetId: budgetDoc.id,
      );
    }

    _isProcessingAlerts = false;
  }

  Widget _buildBudgetOverviewCard({
    required double totalBudget,
    required double totalSpent,
    required CurrencyProvider currency,
  }) {
    final remaining = totalBudget - totalSpent;

    final progress = totalBudget <= 0
        ? 0.0
        : (totalSpent / totalBudget).clamp(0.0, 1.0);

    final usedPercent = totalBudget <= 0
        ? 0
        : ((totalSpent / totalBudget) * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Monthly Budget',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '${currency.currencySymbol} ${currency.convert(totalBudget).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total Spent',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '${currency.currencySymbol} ${currency.convert(totalSpent).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              color: const Color(0xFF3B82F6),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$usedPercent% used',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
              ),

              Text(
                '${currency.currencySymbol} ${remaining.toStringAsFixed(0)} remaining',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards({
    required int onTrackCount,
    required int nearLimitCount,
    required int overBudgetCount,
  }) {
    Widget card({
      required String title,
      required int count,
      required Color color,
      required Color bgColor,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          title: 'On Track',
          count: onTrackCount,
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFFF0FDF4),
        ),

        const SizedBox(width: 8),

        card(
          title: 'Near Limit',
          count: nearLimitCount,
          color: const Color(0xFFF97316),
          bgColor: const Color(0xFFFFF7ED),
        ),

        const SizedBox(width: 8),

        card(
          title: 'Over Budget',
          count: overBudgetCount,
          color: const Color(0xFFEF4444),
          bgColor: const Color(0xFFFEF2F2),
        ),
      ],
    );
  }

  Widget _buildActiveBudgetCard({
    required Map<String, dynamic> budget,
    required String budgetDocId,
    required List<Map<String, dynamic>> categories,
    required double spent,
    required CurrencyProvider currency,
  }) {
    final categoryId = budget['category_id']?.toString() ?? '';
    final categoryName = budget['category_name']?.toString() ?? 'Unknown';

    final matchedCategory = categories.firstWhere(
      (cat) => cat['id'].toString() == categoryId,
      orElse: () => {
        'id': categoryId,
        'name': categoryName,
        'icon': '📌',
        'color': '#F97316',
      },
    );

    final budgetAmount =
        (budget['budget_amount'] as num?)?.toDouble() ??
        (budget['limit'] as num?)?.toDouble() ??
        0;

    final alertPercentage =
        (budget['alert_percentage'] as num?)?.toDouble() ??
        (budget['alert_percent'] as num?)?.toDouble() ??
        80;

    final progress = budgetAmount <= 0
        ? 0.0
        : (spent / budgetAmount).clamp(0.0, 1.0);

    final usedPercent = budgetAmount <= 0
        ? 0
        : ((spent / budgetAmount) * 100).round();
    final remaining = budgetAmount - spent;

    final isNearLimit = usedPercent >= alertPercentage && usedPercent < 100;
    final isOverLimit = usedPercent >= 100;

    Color borderColor;
    Color bgColor;
    Color progressColor;
    String statusText;
    Color statusColor;

    if (isOverLimit) {
      borderColor = const Color(0xFFFCA5A5);
      bgColor = const Color(0xFFFEF2F2);
      progressColor = const Color(0xFFEF4444);
      statusText = 'Over limit';
      statusColor = const Color(0xFFEF4444);
    } else if (isNearLimit) {
      borderColor = const Color(0xFFFDBA74);
      bgColor = const Color(0xFFFFF7ED);
      progressColor = const Color(0xFFF59E0B);
      statusText = 'Near limit';
      statusColor = const Color(0xFFF59E0B);
    } else {
      borderColor = const Color(0xFF86EFAC);
      bgColor = const Color(0xFFF0FDF4);
      progressColor = const Color(0xFF22C55E);
      statusText = 'On track';
      statusColor = const Color(0xFF22C55E);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Text(
                  matchedCategory['icon'],
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isNearLimit || isOverLimit
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle,
                          size: 12,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 10, color: statusColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SetBudgetPage(
                        category: {
                          ...matchedCategory,
                          'budget_doc_id': budget['budget_id'],
                          'budget_amount': budgetAmount,
                          'alert_percentage': alertPercentage,
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 18, color: Colors.blue),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Spent: ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                  children: [
                    TextSpan(
                      text:
                          '${currency.currencySymbol} ${currency.convert(spent).toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  text: 'Budget: ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                  children: [
                    TextSpan(
                      text:
                          '${currency.currencySymbol} ${currency.convert(budgetAmount).toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: progressColor,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$usedPercent% used',
                style: TextStyle(fontSize: 10, color: progressColor),
              ),
              Text(
                remaining >= 0
                    ? '${currency.currencySymbol} ${remaining.toStringAsFixed(0)} left'
                    : 'Over by ${currency.currencySymbol} ${remaining.abs().toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final Color categoryColor = _hexToColor(category['color']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SetBudgetPage(category: category)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: categoryColor.withOpacity(0.15),
              child: Text(
                category['icon'],
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category['name'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const Text(
                    "Tap to set a budget",
                    style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add, size: 22, color: Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Get currency provider
    final currency = Provider.of<CurrencyProvider>(context);

    if (uid == null) {
      return const Center(child: Text('Please login first'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadCategories(),
      builder: (context, categorySnapshot) {
        if (!categorySnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
          );
        }

        final categories = categorySnapshot.data ?? [];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _budgetStream(),
          builder: (context, budgetSnapshot) {
            if (budgetSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              );
            }

            final budgets = budgetSnapshot.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _expenseStream(),
              builder: (context, expenseSnapshot) {
                final expenses = expenseSnapshot.data?.docs ?? [];

                final budgetCategoryIds = budgets
                    .map((doc) => doc.data()['category_id']?.toString() ?? '')
                    .where((id) => id.isNotEmpty)
                    .toList();

                final remainingCategories = categories.where((category) {
                  return !budgetCategoryIds.contains(category['id'].toString());
                }).toList();

                int onTrackCount = 0;
                int nearLimitCount = 0;
                int overBudgetCount = 0;
                double totalBudget = 0;
                double totalSpent = 0;

                for (final budgetDoc in budgets) {
                  final budget = budgetDoc.data();

                  final categoryId = budget['category_id']?.toString() ?? '';

                  final categoryName =
                      budget['category_name']?.toString() ?? '';

                  final spent = _calculateMonthlySpent(
                    expenses,
                    categoryId,
                    categoryName,
                  );

                  final budgetAmount =
                      (budget['budget_amount'] as num?)?.toDouble() ??
                      (budget['limit'] as num?)?.toDouble() ??
                      0;

                  totalBudget += budgetAmount;
                  totalSpent += spent;

                  final alertPercentage =
                      (budget['alert_percentage'] as num?)?.toDouble() ??
                      (budget['alert_percent'] as num?)?.toDouble() ??
                      80;

                  final usedPercent = budgetAmount <= 0
                      ? 0
                      : ((spent / budgetAmount) * 100);

                  if (usedPercent >= 100) {
                    overBudgetCount++;
                  } else if (usedPercent >= alertPercentage) {
                    nearLimitCount++;
                  } else {
                    onTrackCount++;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildBudgetOverviewCard(
                        totalBudget: totalBudget,
                        totalSpent: totalSpent,
                        currency: currency,
                      ),

                      const SizedBox(height: 16),

                      /// SUMMARY CARDS
                      _buildSummaryCards(
                        onTrackCount: onTrackCount,
                        nearLimitCount: nearLimitCount,
                        overBudgetCount: overBudgetCount,
                      ),

                      const SizedBox(height: 20),

                      /// ACTIVE BUDGETS
                      if (budgets.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "ACTIVE BUDGETS",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: Color(0xFF374151),
                              ),
                            ),
                            Text(
                              "${budgets.length} categories",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        ...budgets.map((budgetDoc) {
                          final budget = budgetDoc.data();

                          final categoryId =
                              budget['category_id']?.toString() ?? '';

                          final categoryName =
                              budget['category_name']?.toString() ?? '';

                          final spent = _calculateMonthlySpent(
                            expenses,
                            categoryId,
                            categoryName,
                          );

                          return _buildActiveBudgetCard(
                            budget: budget,
                            budgetDocId: budgetDoc.id,
                            categories: categories,
                            spent: spent,
                            currency: currency,
                          );
                        }),
                      ],

                      /// NO BUDGET SET
                      if (remainingCategories.isNotEmpty) ...[
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "NO BUDGET SET",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            Text(
                              "${remainingCategories.length} categories",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        ...remainingCategories.map((category) {
                          return _buildCategoryCard(category);
                        }),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 55, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF3B82F6)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Budget",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Manage your category spending limits",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _budgetSub?.cancel();
    _expenseSub?.cancel();
    super.dispose();
  }
}
