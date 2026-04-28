import 'package:expensetracker_app/views/pages/manual_entry_page.dart';
import 'package:expensetracker_app/views/pages/voice_input_page.dart';
import 'package:flutter/material.dart';
import 'package:expensetracker_app/views/pages/home_page.dart';
import 'package:expensetracker_app/views/pages/transactions_page.dart';
import 'package:expensetracker_app/views/pages/analytics_page.dart';
import 'package:expensetracker_app/views/pages/reports_page.dart';

class NavbarWidget extends StatefulWidget {
  const NavbarWidget({super.key});

  /// Allows switching tabs from other parts of the app
  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_NavbarWidgetState>();
    state?.onItemTapped(index);
  }

  @override
  State<NavbarWidget> createState() => _NavbarWidgetState();
}

class _NavbarWidgetState extends State<NavbarWidget> {
  /// Keeps track of the currently selected tab
  int selectedIndex = 0;

  /// List of main pages displayed in the app
  final List<Widget> pages = const [
    HomePage(),
    TransactionsPage(),
    AnalyticsPage(),
    ReportsPage(),
  ];

  /// Updates the selected tab
  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  /// Shows a bottom modal for adding a new expense
  void showAddExpenseModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Modal header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Add Expense",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// Option 1: Voice input
              buildModalOption(
                icon: Icons.mic,
                title: "Voice Input",
                subtitle: "Say your expense naturally",
                backgroundColor: const Color(0xFFFCE7F3),
                borderColor: const Color(0xFFFBCFE8),
                iconBgColor: const Color(0xFFFFD2EB),
                iconColor: const Color(0xFFDB2777),
                page: const VoiceInputPage(),
              ),

              const SizedBox(height: 15),

              /// Option 2: Manual entry
              buildModalOption(
                icon: Icons.edit,
                title: "Manual Entry",
                subtitle: "Type in your expense details",
                backgroundColor: const Color(0xFFF3E8FF),
                borderColor: const Color(0xFFE9D5FF),
                iconBgColor: const Color(0xFFE3D0FF),
                iconColor: const Color(0xFF7C3AED),
                page: const ManualEntryPage(),
              ),

              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }

  /// Builds each option inside the modal (voice or manual)
  Widget buildModalOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color borderColor,
    required Color iconBgColor,
    required Color iconColor,
    required Widget page,
  }) {
    return Builder(
      builder: (parentContext) {
        return GestureDetector(
          onTap: () {
            // Close modal first
            Navigator.pop(parentContext);

            // Ensure widget is still mounted before navigation
            if (!mounted) return;

            // Navigate to selected page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                /// Icon circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),

                const SizedBox(width: 16),

                /// Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          )),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          )),
                    ],
                  ),
                ),

                /// Arrow icon
                const Icon(Icons.chevron_right,
                    size: 20, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds each item in the bottom navigation bar
  Widget buildNavItem(IconData icon, String label, int index) {
    bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF2F6BFF)
                  : const Color(0xFF9E9E9E),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2F6BFF)
                    : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// Prevents UI from shifting when keyboard appears
      resizeToAvoidBottomInset: false,

      /// Keeps all pages alive and switches between them
      body: IndexedStack(index: selectedIndex, children: pages),

      /// Floating button in the center for adding expenses
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 15),
        child: GestureDetector(
          onTap: () => showAddExpenseModal(context),
          child: Container(
            height: 65,
            width: 65,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF9B5CF6), Color(0xFFFF4D8D)],
              ),
            ),
            child: const Icon(Icons.add, size: 36, color: Colors.white),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      /// Bottom navigation bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        height: 90,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FA),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            buildNavItem(Icons.home_outlined, "Home", 0),
            buildNavItem(Icons.history, "Transactions", 1),
            const SizedBox(width: 50),
            buildNavItem(Icons.pie_chart_outline, "Analytics", 2),
            buildNavItem(Icons.description_outlined, "Reports", 3),
          ],
        ),
      ),
    );
  }
}