import 'package:flutter/material.dart';

/// Help Center screen providing FAQs and support access
class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),

      // Main layout structure
      body: Column(
        children: [

          /// Top header with gradient background and back navigation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
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
                  "Help Center",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          /// Scrollable content section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),

              child: Column(
                children: [

                  /// Search input field for help topics
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: const TextField(
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search, color: Colors.grey),
                        hintText: "Search for help...",
                        hintStyle: TextStyle(fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Frequently asked help categories
                  buildHelpCard(
                    emoji: "🚀",
                    title: "Getting Started",
                    description:
                        "Learn the basics of ExpenseAI and how to track your first expense",
                    color: Colors.blue,
                  ),

                  buildHelpCard(
                    emoji: "🎤",
                    title: "Voice Features",
                    description:
                        "How to use voice input and AI-powered expense recognition",
                    color: Colors.purple,
                  ),

                  buildHelpCard(
                    emoji: "📷",
                    title: "Receipt Scanning",
                    description:
                        "Tips for scanning receipts and using OCR features",
                    color: Colors.green,
                  ),

                  buildHelpCard(
                    emoji: "📊",
                    title: "Reports & Analytics",
                    description:
                        "Understanding your spending patterns and exporting data",
                    color: Colors.orange,
                  ),

                  buildHelpCard(
                    emoji: "⚙️",
                    title: "Account & Settings",
                    description:
                        "Manage your profile, security, and preferences",
                    color: Colors.red,
                  ),

                  const SizedBox(height: 20),

                  /// Contact support section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      children: [
                        const Text("💬", style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 10),

                        const Text(
                          "Still Need Help?",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          "Our support team is here to help you",
                          style: TextStyle(color: Colors.grey),
                        ),

                        const SizedBox(height: 16),

                        /// Button to contact support (action not implemented yet)
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "Contact Support",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
    );
  }

  /// Reusable card widget for displaying help topics
  Widget buildHelpCard({
    required String emoji,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// Icon container with background tint
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),

          const SizedBox(width: 12),

          /// Title and description content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "View Articles →",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}