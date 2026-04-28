import 'package:expensetracker_app/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

// Manual expense entry page
// Lets user enter amount, category, date, merchant, and description
class ManualEntryPage extends StatefulWidget {
  const ManualEntryPage({super.key});

  @override
  State<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends State<ManualEntryPage> {
  // Controllers for text input fields
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController merchantController = TextEditingController();

  // Default selected date is today
  DateTime selectedDate = DateTime.now();

  // Stores selected category ID
  String? selectedCategoryId;

  // Stores the full selected category document
  // Useful for showing selected category first in the UI
  DocumentSnapshot? selectedCategoryDoc;

  // Show modal dialog with all categories
  void showAllCategoriesModal(List categories) {
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

                // Scrollable category list
                SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 8,
                      children: categories.map<Widget>((category) {
                        final emoji = category['icon'] as String;
                        final isSelected = selectedCategoryId == category.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCategoryId = category.id;
                              selectedCategoryDoc = category;
                            });
                            Navigator.pop(context);
                          },
                          child: buildCategoryChip(
                            emoji,
                            category['category_name'],
                            isSelected,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  // Open date picker and update selected date
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),

      // Custom date picker theme
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9333EA),
              onPrimary: Colors.white,
              surface: Color(0xFFF9FAFB),
              onSurface: Colors.black,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // Save expense into Firestore
  void saveExpense() async {
    final amountText = amountController.text.trim();
    final description = descriptionController.text.trim();
    final merchant = merchantController.text.trim();

    // Validate required fields
    if (amountText.isEmpty || selectedCategoryId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter amount and select category"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Current user ID
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Generate a new expense document ID
      String expenseId = FirebaseFirestore.instance
          .collection("Expenses")
          .doc()
          .id;

      // Parse input amount
      double? inputAmount = double.tryParse(amountText);

      // Validate amount
      if (inputAmount == null || inputAmount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Amount must be greater than 0"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Get current currency provider
      final currency = Provider.of<CurrencyProvider>(context, listen: false);

      // Convert entered amount into base currency (MYR) before saving
      double amountInRM = currency.convertToBase(inputAmount);

      // Build expense data map
      Map<String, dynamic> expenseInfoMap = {
        "expense_id": expenseId,
        "uid": uid,
        "amount": amountInRM,
        "original_amount": inputAmount,
        "original_currency": currency.currencyCode,
        "category_id": selectedCategoryId,
        "merchant": merchant,
        "description": description,
        "expense_date": selectedDate,
        "createdAt": FieldValue.serverTimestamp(),
      };

      // Save to database service
      await DatabaseMethods().addExpense(expenseId, expenseInfoMap);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Expense added successfully"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Close page after saving
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      // Show error message if save fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to currency changes for live UI update
    final currency = Provider.of<CurrencyProvider>(context);

    // Try to parse entered amount
    double? input = double.tryParse(amountController.text);

    // Convert typed amount to MYR for preview
    double? converted = input != null ? currency.convertToBase(input) : null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // Top header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
              ),
            ),
            child: Row(
              children: [
                // Close button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                // Page title
                const Expanded(
                  child: Center(
                    child: Text(
                      "Add Expense",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Save button
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: saveExpense,
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [
                // Main form section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Amount card
                        buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Amount",
                                style: TextStyle(color: Colors.black54),
                              ),
                              Row(
                                children: [
                                  // Current currency code
                                  Text(
                                    currency.currencyCode,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 5),

                                  // Amount input
                                  Expanded(
                                    child: TextField(
                                      controller: amountController,
                                      autofocus: true,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d*\.?\d{0,2}'),
                                        ),
                                      ],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: "0.00",
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Show MYR preview if user is using another currency
                              if (converted != null &&
                                  currency.currencyCode != "MYR")
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(
                                    "≈ RM ${converted.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Category card
                        buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Category",
                                style: TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 10),

                              // Load categories from Firestore
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('Categories')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const CircularProgressIndicator();
                                  }

                                  final categories = snapshot.data!.docs;

                                  // Sort categories alphabetically
                                  categories.sort(
                                    (a, b) => (a['category_name'] as String)
                                        .toLowerCase()
                                        .compareTo(
                                          (b['category_name'] as String)
                                              .toLowerCase(),
                                        ),
                                  );

                                  // Rebuild visible list with selected category shown first
                                  List<DocumentSnapshot> visibleCategories = [];

                                  if (selectedCategoryDoc != null) {
                                    visibleCategories.add(selectedCategoryDoc!);
                                  }

                                  visibleCategories.addAll(
                                    categories
                                        .where(
                                          (cat) => cat.id != selectedCategoryId,
                                        )
                                        .take(
                                          selectedCategoryDoc != null ? 9 : 10,
                                        ),
                                  );

                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      // Show selected / top categories
                                      ...visibleCategories.map((category) {
                                        final emoji = category['icon'];
                                        final isSelected =
                                            selectedCategoryId == category.id;

                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              selectedCategoryId = category.id;
                                              selectedCategoryDoc = category;
                                            });
                                          },
                                          child: buildCategoryChip(
                                            emoji,
                                            category['category_name'],
                                            isSelected,
                                          ),
                                        );
                                      }),

                                      // More button opens full category modal
                                      GestureDetector(
                                        onTap: () {
                                          showAllCategoriesModal(categories);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.more_horiz, size: 12),
                                              SizedBox(width: 6),
                                              Text(
                                                "More",
                                                style: TextStyle(fontSize: 12),
                                              ),
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
                        ),

                        const SizedBox(height: 16),

                        // Date card
                        buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Date",
                                style: TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 8),

                              // Tap to open date picker
                              GestureDetector(
                                onTap: pickDate,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(selectedDate),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Merchant card
                        buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Merchant (Optional)",
                                style: TextStyle(color: Colors.black54),
                              ),
                              TextField(
                                controller: merchantController,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "Merchant or store name",
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: Colors.black12,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Description card
                        buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Description (Optional)",
                                style: TextStyle(color: Colors.black54),
                              ),
                              TextField(
                                controller: descriptionController,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "Add a note",
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: Colors.black12,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reusable card container used by all form sections
  Widget buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  // Reusable category chip widget
  Widget buildCategoryChip(String emoji, String name, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF9333EA) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji icon
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),

          // Category label
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers when leaving page
    amountController.dispose();
    descriptionController.dispose();
    merchantController.dispose();
    super.dispose();
  }
}