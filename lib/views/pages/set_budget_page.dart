import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

class SetBudgetPage extends StatefulWidget {
  final Map<String, dynamic> category;

  const SetBudgetPage({super.key, required this.category});

  @override
  State<SetBudgetPage> createState() => _SetBudgetPageState();
}

class _SetBudgetPageState extends State<SetBudgetPage> {
  final TextEditingController amountController = TextEditingController();

  double budgetAmount = 250;
  double alertPercent = 80;

  late final Stream<double> monthlySpentStream;

  final List<double> quickAmounts = [200, 300, 500, 700, 1000, 1500];

  bool get isEditingBudget => widget.category['budget_doc_id'] != null;

  @override
  void initState() {
    super.initState();

    budgetAmount =
        (widget.category['budget_amount'] as num?)?.toDouble() ?? 250;

    alertPercent =
        (widget.category['alert_percentage'] as num?)?.toDouble() ?? 80;

    amountController.text = budgetAmount.toStringAsFixed(0);

    monthlySpentStream = _getMonthlyCategorySpent();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final currency = Provider.of<CurrencyProvider>(context, listen: false);

    final existingBudgetDocId = widget.category['budget_doc_id'];

    final budgetInBase = currency.convertToBase(budgetAmount);

    if (existingBudgetDocId != null) {
      await FirebaseFirestore.instance
          .collection('Budgets')
          .doc(existingBudgetDocId)
          .update({
            'budget_amount': budgetInBase,
            'alert_percentage': alertPercent,
            'updatedAt': FieldValue.serverTimestamp(),
            'budgetState': 'on_track',
            'lastAlertAt': FieldValue.serverTimestamp(),
          });
    } else {
      final existingBudget = await FirebaseFirestore.instance
          .collection('Budgets')
          .where('uid', isEqualTo: uid)
          .where('category_id', isEqualTo: widget.category['id'])
          .limit(1)
          .get();

      if (existingBudget.docs.isNotEmpty) {
        await existingBudget.docs.first.reference.update({
          'budget_amount': budgetInBase,
          'alert_percentage': alertPercent,
          'updatedAt': FieldValue.serverTimestamp(),
          'budgetState': 'on_track',
          'lastAlertAt': FieldValue.serverTimestamp(),
        });
      } else {
        final budgetRef = FirebaseFirestore.instance
            .collection('Budgets')
            .doc();

        await budgetRef.set({
          'budget_id': budgetRef.id,
          'uid': uid,
          'category_id': widget.category['id'],
          'category_name': widget.category['name'],
          'budget_amount': budgetInBase,
          'alert_percentage': alertPercent,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'budgetState': 'on_track',
          'lastAlertAt': FieldValue.serverTimestamp(),
        });
      }
    }

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Budget saved successfully'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatAmount(BuildContext context, double amount) {
    final currency = Provider.of<CurrencyProvider>(context, listen: false);
    return currency.convert(amount).toStringAsFixed(0);
  }

  String _formatAmountWithDecimal(BuildContext context, double amount) {
    final currency = Provider.of<CurrencyProvider>(context, listen: false);
    return currency.convert(amount).toStringAsFixed(2);
  }

  Stream<double> _getMonthlyCategorySpent() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Stream.value(0);
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

    final selectedCategoryId = widget.category['id']?.toString();
    final selectedCategoryName = widget.category['name']?.toString();

    return FirebaseFirestore.instance
        .collection('Expenses')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          double total = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();

            final expenseCategoryId = data['category_id']?.toString();
            final expenseCategoryName = data['category_name']?.toString();

            final isSameCategory =
                expenseCategoryId == selectedCategoryId ||
                expenseCategoryName == selectedCategoryName;

            if (!isSameCategory) continue;

            final expenseDateValue = data['expense_date'];
            DateTime? expenseDate;

            if (expenseDateValue is Timestamp) {
              expenseDate = expenseDateValue.toDate();
            } else if (expenseDateValue is DateTime) {
              expenseDate = expenseDateValue;
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
        });
  }

  Future<void> _deleteBudget() async {
    final budgetDocId = widget.category['budget_doc_id'];
    if (budgetDocId == null) return;

    await FirebaseFirestore.instance
        .collection('Budgets')
        .doc(budgetDocId)
        .delete();

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Budget removed successfully'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF3B82F6)],
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Set ${widget.category['name']} Budget',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _amountCard(),
                  const SizedBox(height: 16),
                  _previewCard(),
                  const SizedBox(height: 16),
                  _alertCard(),
                  if (isEditingBudget) ...[
                    const SizedBox(height: 16),
                    _deleteBudgetButton(),
                  ],
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Save Budget — ${currency.currencySymbol} ${currency.convert(budgetAmount).toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _amountCard() {
    final currency = Provider.of<CurrencyProvider>(context);

    String format(double amount) {
      final converted = currency.convert(amount);
      return converted.toStringAsFixed(0);
    }

    // the key fix (convert for display)
    final displayAmount = currency.convert(budgetAmount);

    // keep controller in sync
    amountController.value = TextEditingValue(
      text: displayAmount.toStringAsFixed(0),
      selection: TextSelection.collapsed(
        offset: displayAmount.toStringAsFixed(0).length,
      ),
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Budget Amount',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
            decoration: InputDecoration(
              prefixText: '${currency.currencySymbol} ',
              prefixStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              final amount = double.tryParse(value);
              setState(() {
                // store BASE value only
                budgetAmount = currency.convertToBase(amount ?? 0);
              });
            },
          ),

          const SizedBox(height: 12),

          GridView.builder(
            padding: const EdgeInsets.only(top: 12),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quickAmounts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.6,
            ),
            itemBuilder: (context, index) {
              final amount = quickAmounts[index];

              return SizedBox(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      budgetAmount = amount;
                      amountController.text = format(amount);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    side: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '${currency.currencySymbol} ${format(amount)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final currency = Provider.of<CurrencyProvider>(context, listen: false);
    return StreamBuilder<double>(
      stream: monthlySpentStream,
      builder: (context, snapshot) {
        final spent = snapshot.data ?? 0;
        final progress = budgetAmount <= 0
            ? 0.0
            : (spent / budgetAmount).clamp(0.0, 1.0);
        final usedPercent = (progress * 100).round();
        final remainingAmount = budgetAmount - spent;

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Spent so far: ',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${currency.currencySymbol} ${_formatAmountWithDecimal(context, spent)}',
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: 'Budget: ',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
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

              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 14,
                  backgroundColor: const Color(0xFFF3F4F6),
                  color: progress >= 1
                      ? const Color(0xFFEF4444)
                      : progress >= (alertPercent / 100)
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF22C55E),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$usedPercent% used',
                    style: TextStyle(
                      fontSize: 10,
                      color: progress >= 1
                          ? const Color(0xFFEF4444) // Red
                          : progress >= (alertPercent / 100)
                          ? const Color(0xFFF59E0B) // Orange
                          : const Color(0xFF16A34A), // Green
                    ),
                  ),
                  Text(
                    remainingAmount >= 0
                        ? '${currency.currencySymbol} ${_formatAmountWithDecimal(context, remainingAmount)} remaining'
                        : 'Over by ${currency.currencySymbol} ${_formatAmountWithDecimal(context, remainingAmount.abs())}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _alertCard() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Alert me when',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                '${alertPercent.round()}%',
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                overlayShape: SliderComponentShape.noOverlay,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: alertPercent,
                min: 50,
                max: 100,
                divisions: 5,
                activeColor: const Color(0xFF3B82F6),
                inactiveColor: const Color(0xFFE5E7EB),
                onChanged: (value) {
                  setState(() {
                    alertPercent = value;
                  });
                },
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '50%',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                Text(
                  'spent is reached',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
                Text(
                  '100%',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _deleteBudgetButton() {
    final categoryName = widget.category['name'] ?? 'this category';

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _deleteBudget,
        icon: const Icon(Icons.delete_outline, size: 18),
        label: Text('Remove Budget for $categoryName'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF4444),
          backgroundColor: const Color(0xFFFEF2F2),
          side: const BorderSide(color: Color(0xFFFCA5A5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
