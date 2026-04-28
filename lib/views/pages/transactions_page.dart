import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

// Constants
const _primaryGradient = LinearGradient(
  colors: [Color(0xFF6366F1), Color(0xFF9333EA)],
);

const _editGradient = LinearGradient(
  colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
);

const _primaryColor = Color(0xFF6366F1);
const _primaryLight = Color(0xFFE0E7FF);
const _purpleAccent = Color(0xFF9333EA);
const _purpleLight = Color(0xFFF3E8FF);
const _cardBackground = Color(0xFFF9FAFB);

// HistoryPage
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  CurrencyProvider get currencyProvider =>
      Provider.of<CurrencyProvider>(context, listen: false);
  // Auth
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  // Cache
  final Map<String, Map<String, dynamic>> _categoryCache = {};

  // Final state
  String _selectedFilter = 'All';
  String _searchQuery = '';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  final List<String> _selectedCategoryIds = [];
  double? _minAmount;
  double? _maxAmount;

  // Firestore streams
  Stream<QuerySnapshot> get _expensesStream => FirebaseFirestore.instance
      .collection('Expenses')
      .where('uid', isEqualTo: _uid)
      .orderBy('expense_date', descending: true)
      .snapshots();

  Stream<QuerySnapshot> get _categoriesStream => FirebaseFirestore.instance
      .collection('Categories')
      .orderBy('category_name')
      .snapshots();

  // Data helpers

  /// Fetches a category document, using the in-memory cache when available.
  Future<Map<String, dynamic>?> _fetchCategory(String categoryId) async {
    if (_categoryCache.containsKey(categoryId)) {
      return _categoryCache[categoryId];
    }

    final doc = await FirebaseFirestore.instance
        .collection('Categories')
        .doc(categoryId)
        .get();

    if (doc.exists) {
      _categoryCache[categoryId] = doc.data()!;
      return doc.data();
    }

    return null;
  }

  /// Converts a hex color string (with or without #) to a Flutter [Color].
  Color _hexToColor(String hex) {
    final sanitized = hex.replaceAll('#', '');
    final withAlpha = sanitized.length == 6 ? 'FF$sanitized' : sanitized;
    return Color(int.parse(withAlpha, radix: 16));
  }

  /// Groups a flat list of expense documents by date label (Today / Yesterday / formatted date).
  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
    List<QueryDocumentSnapshot> docs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<QueryDocumentSnapshot>> grouped = {};

    for (final doc in docs) {
      final date = (doc['expense_date'] as Timestamp).toDate();
      final dateOnly = DateTime(date.year, date.month, date.day);

      final String label;
      if (dateOnly == today) {
        label = 'Today';
      } else if (dateOnly == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMM d, yyyy').format(dateOnly);
      }

      grouped.putIfAbsent(label, () => []).add(doc);
    }

    return grouped;
  }

  /// Sums the `amount` field of all documents in [docs].
  double _calculateTotal(List<QueryDocumentSnapshot> docs) =>
      docs.fold(0.0, (total, doc) => total + (doc['amount'] as num).toDouble());

  // Filtering & searching

  /// Returns only the documents that pass the currently active date/category/amount filters.
  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    var result = List<QueryDocumentSnapshot>.from(docs);

    // Date filter
    switch (_selectedFilter) {
      case 'Today':
        final today = DateTime(now.year, now.month, now.day);
        result = result.where((doc) {
          final date = (doc['expense_date'] as Timestamp).toDate();
          return DateTime(date.year, date.month, date.day) == today;
        }).toList();
        break;

      case 'This Week':
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        result = result.where((doc) {
          return (doc['expense_date'] as Timestamp).toDate().isAfter(
            startOfWeek.subtract(const Duration(seconds: 1)),
          );
        }).toList();
        break;

      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        result = result.where((doc) {
          return (doc['expense_date'] as Timestamp).toDate().isAfter(
            startOfMonth.subtract(const Duration(seconds: 1)),
          );
        }).toList();
        break;

      case 'Custom':
        if (_customStartDate != null && _customEndDate != null) {
          result = result.where((doc) {
            final date = (doc['expense_date'] as Timestamp).toDate();
            return date.isAfter(
                  _customStartDate!.subtract(const Duration(seconds: 1)),
                ) &&
                date.isBefore(_customEndDate!.add(const Duration(days: 1)));
          }).toList();
        }
        break;
    }

    // Category filter
    if (_selectedCategoryIds.isNotEmpty) {
      result = result
          .where((doc) => _selectedCategoryIds.contains(doc['category_id']))
          .toList();
    }

    // Amount range filter
    if (_minAmount != null) {
      result = result.where((doc) {
        final convertedAmount = currencyProvider.convert(
          (doc['amount'] as num).toDouble(),
        );
        return convertedAmount >= _minAmount!;
      }).toList();
    }

    if (_maxAmount != null) {
      result = result.where((doc) {
        final convertedAmount = currencyProvider.convert(
          (doc['amount'] as num).toDouble(),
        );
        return convertedAmount <= _maxAmount!;
      }).toList();
    }

    return result;
  }

  /// Returns only the documents whose description or category name contain [_searchQuery].
  List<QueryDocumentSnapshot> _applySearch(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final description = (data['description'] as String? ?? '').toLowerCase();
      final categoryName =
          _categoryCache[data['category_id']]?['category_name']
              ?.toString()
              .toLowerCase() ??
          '';

      return description.contains(_searchQuery) ||
          categoryName.contains(_searchQuery);
    }).toList();
  }

  // Modals

  /// Shows the filter bottom sheet (categories + amount range).
  void _showFilterSheet() {
    final minController = TextEditingController(
      text: _minAmount?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: _maxAmount?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildFilterSheetHeader(context),
                const SizedBox(height: 20),
                _buildCategorySection(setModalState),
                const SizedBox(height: 25),
                _buildAmountRangeSection(minController, maxController),
                const SizedBox(height: 25),
                _buildFilterSheetActions(context, minController, maxController),
                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows the edit expense bottom sheet pre-populated with [expenseDoc] data.
  void _showEditSheet(DocumentSnapshot expenseDoc) {
    final data = expenseDoc.data() as Map<String, dynamic>;

    double? converted;

    final amountController = TextEditingController(
      text: currencyProvider
          .convert((data['amount'] as num).toDouble())
          .toStringAsFixed(2),
    );

    final descriptionController = TextEditingController(
      text: data['description'] ?? '',
    );

    final merchantController = TextEditingController(
      text: data['merchant'] ?? '',
    );

    DateTime selectedDate = (data['expense_date'] as Timestamp).toDate();
    String selectedCategoryId = data['category_id'];

    void updateConverted() {
      final input = double.tryParse(amountController.text);
      if (input != null) {
        converted = currencyProvider.convertToBase(input);
      } else {
        converted = null;
      }
    }

    // initialize
    updateConverted();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // add listener only once
            amountController.removeListener(updateConverted);
            amountController.addListener(() {
              setModalState(() {
                updateConverted();
              });
            });

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Container(
                height: MediaQuery.of(context).size.height,
                color: const Color(0xFFF3F4F6),
                child: Column(
                  children: [
                    _buildEditSheetHeader(
                      context: sheetContext,
                      parentContext: this.context,
                      amountController: amountController,
                      descriptionController: descriptionController,
                      merchantController: merchantController,
                      expenseDoc: expenseDoc,
                      selectedCategoryId: selectedCategoryId,
                      selectedDate: selectedDate,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildAmountCard(amountController, converted),
                            const SizedBox(height: 16),

                            _buildCategoryCard(
                              setModalState,
                              selectedCategoryId,
                              (id) => selectedCategoryId = id,
                            ),

                            const SizedBox(height: 16),

                            _buildDateCard(
                              context,
                              setModalState,
                              selectedDate,
                              (d) => selectedDate = d,
                            ),

                            const SizedBox(height: 16),

                            _buildMerchantCard(merchantController),

                            const SizedBox(height: 16),

                            _buildDescriptionCard(descriptionController),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows a confirmation dialog before deleting doc
  void _showDeleteDialog(QueryDocumentSnapshot doc) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDeleteIcon(),
                  const SizedBox(height: 16),
                  const Text(
                    'Delete Record?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to delete this record?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  _buildDeleteDialogActions(context, doc),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Shared small widgets
  Widget _buildCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _buildCategoryChip(String emoji, String name, bool isSelected) =>
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ), // smaller
        decoration: BoxDecoration(
          color: isSelected ? _purpleLight : _cardBackground,
          borderRadius: BorderRadius.circular(18), // slightly smaller
          border: Border.all(
            color: isSelected ? _purpleAccent : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );

  Widget _buildAmountRangeFields(
    TextEditingController minController,
    TextEditingController maxController,
  ) => Row(
    children: [
      Expanded(child: _buildAmountField(minController, label: 'Min')),
      const SizedBox(width: 10),
      Expanded(child: _buildAmountField(maxController, label: 'Max')),
    ],
  );

  Widget _buildAmountField(
    TextEditingController controller, {
    required String label,
  }) => SizedBox(
    height: 40,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),

      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],

      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        prefixText: '${currencyProvider.currencySymbol} ',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );

  // Header
  Widget _buildPageHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: _primaryGradient),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 35),
        Text(
          'Transactions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'View and manage your expense history',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );

  // Transaction list widgets
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return GestureDetector(
      onTap: () => _onFilterChipTapped(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _onFilterChipTapped(String label) async {
    if (label == 'Custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (!mounted) return;
      if (picked != null) {
        setState(() {
          _selectedFilter = 'Custom';
          _customStartDate = picked.start;
          _customEndDate = picked.end;
        });
      }
    } else {
      setState(() => _selectedFilter = label);
    }
  }

  Widget _buildGroupSection(String title, List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              '${currencyProvider.currencySymbol} ${currencyProvider.convert(_calculateTotal(docs)).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...docs.map(_buildTransactionItem),
      ],
    );
  }

  Widget _buildTransactionItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final amount = (data['amount'] as num).toDouble();
    final date = (data['expense_date'] as Timestamp).toDate();
    final categoryId = data['category_id'];

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchCategory(categoryId),
      builder: (context, snapshot) {
        final category = snapshot.data;

        final name = category?['category_name'] ?? 'Unknown';
        final emoji = category?['icon'] ?? '❓';

        final bgColor = category?['color'] != null
            ? _hexToColor(category!['color']).withValues(alpha: 0.15)
            : Colors.grey[200]!;

        final merchant = data['merchant']?.toString() ?? '';

        final title = merchant.isNotEmpty ? merchant : name;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            children: [
              _buildCategoryAvatar(emoji, bgColor),
              const SizedBox(width: 12),
              _buildTransactionInfo(title, date),
              _buildTransactionActions(doc, amount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionInfo(String title, DateTime date) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          Text(
            DateFormat('hh:mm a').format(date),
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAvatar(String emoji, Color backgroundColor) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
  );

  Widget _buildTransactionActions(
    QueryDocumentSnapshot doc,
    double amount,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '-${currencyProvider.currencySymbol} ${currencyProvider.convert(amount).toStringAsFixed(2)}',
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 10),
      _buildIconButton(
        icon: Icons.edit,
        color: Colors.blue,
        onTap: () => _showEditSheet(doc),
      ),
      const SizedBox(width: 5),
      _buildIconButton(
        icon: Icons.close,
        color: Colors.red,
        onTap: () => _showDeleteDialog(doc),
      ),
    ],
  );

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 18, color: color),
    ),
  );

  // Filter sheet sub-widgets
  Widget _buildFilterSheetHeader(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        'Filter Transactions',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );

  Widget _buildCategorySection(StateSetter setModalState) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Categories', style: TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 10),
      StreamBuilder<QuerySnapshot>(
        stream: _categoriesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.data!.docs.map((cat) {
                final isSelected = _selectedCategoryIds.contains(cat.id);
                return GestureDetector(
                  onTap: () => setModalState(() {
                    isSelected
                        ? _selectedCategoryIds.remove(cat.id)
                        : _selectedCategoryIds.add(cat.id);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryLight : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? _primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat['icon'], style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          cat['category_name'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    ],
  );

  Widget _buildAmountRangeSection(
    TextEditingController minController,
    TextEditingController maxController,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Amount Range', style: TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 10),
      _buildAmountRangeFields(minController, maxController),
    ],
  );

  Widget _buildFilterSheetActions(
    BuildContext context,
    TextEditingController minController,
    TextEditingController maxController,
  ) => Row(
    children: [
      Expanded(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: () {
            if (!mounted) return;
            setState(() {
              _selectedCategoryIds.clear();
              _minAmount = null;
              _maxAmount = null;
            });
            Navigator.pop(context);
          },
          child: const Text('Clear All', style: TextStyle(fontSize: 12)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            backgroundColor: _primaryColor,
          ),
          onPressed: () {
            final inputMin = double.tryParse(minController.text);
            final inputMax = double.tryParse(maxController.text);

            final min = inputMin;
            final max = inputMax;

            if ((min != null && min <= 0) || (max != null && max <= 0)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Amount must be greater than 0"),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (min != null && max != null && min > max) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Min cannot be greater than Max"),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setState(() {
              _minAmount = min;
              _maxAmount = max;
            });

            Navigator.pop(context);
          },
          child: const Text(
            'Apply Filters',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    ],
  );

  // Edit sheet sub-widgets
  Widget _buildEditSheetHeader({
    required BuildContext context, // sheet context
    required BuildContext parentContext, // main page context
    required TextEditingController amountController,
    required TextEditingController descriptionController,
    required TextEditingController merchantController,
    required DocumentSnapshot expenseDoc,
    required String selectedCategoryId,
    required DateTime selectedDate,
  }) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
        decoration: const BoxDecoration(gradient: _editGradient),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Edit Expense',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: () async {
                final inputAmount = double.tryParse(amountController.text);

                if (inputAmount == null || inputAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Amount must be greater than 0"),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // Convert back to base currency before saving
                final amount = currencyProvider.convertToBase(inputAmount);

                await FirebaseFirestore.instance
                    .collection('Expenses')
                    .doc(expenseDoc.id)
                    .update({
                      'amount': amount,
                      'merchant': merchantController.text,
                      'description': descriptionController.text,
                      'category_id': selectedCategoryId,
                      'expense_date': selectedDate,
                    });

                if (!mounted || !context.mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Expense updated successfully'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(
    TextEditingController controller,
    double? converted,
  ) => _buildCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount', style: TextStyle(color: Colors.black54)),
        Row(
          children: [
            Text(
              currencyProvider.currencyCode,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,7}(\.\d{0,2})?$'),
                  ),
                ],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ],
        ),
        if (converted != null && currencyProvider.currencyCode != "MYR")
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              "≈ RM ${converted.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    ),
  );

  void _showAllCategoriesDialog(
    List categories,
    StateSetter setModalState,
    ValueChanged<String> onChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Category",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map<Widget>((category) {
                    return GestureDetector(
                      onTap: () {
                        setModalState(() {
                          onChanged(category.id);
                        });
                        Navigator.pop(context);
                      },
                      child: _buildCategoryChip(
                        category['icon'],
                        category['category_name'],
                        false,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    StateSetter setModalState,
    String selectedCategoryId,
    ValueChanged<String> onChanged,
  ) => _buildCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(
          stream: _categoriesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final categories = snapshot.data!.docs;

            /// reorder list so selected category is first
            List<DocumentSnapshot> visibleCategories = [];

            if (selectedCategoryId.isNotEmpty) {
              visibleCategories.addAll(
                categories.where((cat) => cat.id == selectedCategoryId),
              );
            }

            visibleCategories.addAll(
              categories.where((cat) => cat.id != selectedCategoryId),
            );

            /// show only first 10
            final firstTen = visibleCategories.take(10).toList();

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...firstTen.map((category) {
                  final isSelected = category.id == selectedCategoryId;

                  return GestureDetector(
                    onTap: () => setModalState(() => onChanged(category.id)),
                    child: _buildCategoryChip(
                      category['icon'],
                      category['category_name'],
                      isSelected,
                    ),
                  );
                }),

                /// MORE BUTTON
                GestureDetector(
                  onTap: () {
                    _showAllCategoriesDialog(
                      categories,
                      setModalState,
                      onChanged,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.more_horiz, size: 12),
                        SizedBox(width: 6),
                        Text("More", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _buildDateCard(
    BuildContext context,
    StateSetter setModalState,
    DateTime selectedDate,
    ValueChanged<DateTime> onChanged,
  ) => _buildCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              if (!mounted) return;
              setModalState(() => onChanged(picked));
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('yyyy-MM-dd').format(selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildMerchantCard(TextEditingController controller) => _buildCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Merchant (Optional)",
          style: TextStyle(color: Colors.black54),
        ),
        TextField(
          controller: controller,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          decoration: const InputDecoration(
            hintText: "Merchant or store name",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.black12, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildDescriptionCard(TextEditingController controller) => _buildCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Description (Optional)",
          style: TextStyle(color: Colors.black54),
        ),
        TextField(
          controller: controller,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          decoration: const InputDecoration(
            hintText: "Add a note",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.black12, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  // Delete dialog sub-widgets
  Widget _buildDeleteIcon() => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.10),
      shape: BoxShape.circle,
    ),
    child: const Center(child: Icon(Icons.close, color: Colors.red, size: 32)),
  );

  Widget _buildDeleteDialogActions(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) => Row(
    children: [
      Expanded(child: _buildCancelButton(context)),
      const SizedBox(width: 12),
      Expanded(child: _buildConfirmDeleteButton(context, doc)),
    ],
  );

  Widget _buildCancelButton(BuildContext context) => InkWell(
    onTap: () => Navigator.pop(context),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'Cancel',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        ),
      ),
    ),
  );

  Widget _buildConfirmDeleteButton(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) => InkWell(
    onTap: () async {
      Navigator.pop(context);
      await FirebaseFirestore.instance
          .collection('Expenses')
          .doc(doc.id)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Expense deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'Delete',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );

  // Build
  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    currencyProvider.currencyCode;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.grey[100],
        body: Column(
          children: [
            _buildPageHeader(),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _expensesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs
                      .cast<QueryDocumentSnapshot>();
                  final filtered = _applyFilters(docs);
                  final searched = _applySearch(filtered);
                  final grouped = _groupByDate(searched);

                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSearchAndFilterRow(),
                      const SizedBox(height: 15),
                      _buildFilterChipRow(),
                      const SizedBox(height: 20),

                      if (searched.isEmpty)
                        const _EmptyState()
                      else
                        ...grouped.entries.map(
                          (entry) => Column(
                            children: [
                              _buildGroupSection(entry.key, entry.value),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterRow() => Row(
    children: [
      Expanded(
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search transactions...',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _showFilterSheet,
        child: Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Icon(Icons.tune, size: 18),
        ),
      ),
    ],
  );

  Widget _buildFilterChipRow() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        'All',
        'Today',
        'This Week',
        'This Month',
        'Custom',
      ].map(_buildFilterChip).toList(),
    ),
  );
}

// EmptyState widget
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 250),
      child: Text('No records found', style: TextStyle(color: Colors.grey)),
    ),
  );
}
