import 'package:flutter/material.dart';

/// Terms of Service Page
/// Displays legal agreement and usage terms for the application
class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// Background color of entire page
      backgroundColor: const Color(0xFFF9FAFB),

      body: Column(
        children: [

          /// Header Section (Top Navigation Bar)
          Container(
            width: double.infinity,

            /// Padding includes top spacing for status bar
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),

            /// Gradient background styling
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF374151), Color(0xFF111827)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),

            child: Row(
              children: [

                /// Back button to return to previous page
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(width: 10),

                /// Page title
                const Text(
                  "Terms of Service",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

           /// Main Content Section
          Expanded(
            child: SingleChildScrollView(

              /// Outer padding for scrollable content
              padding: const EdgeInsets.all(16),

              child: Container(
                padding: const EdgeInsets.all(20),

                /// Card-like styling
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// Last updated timestamp
                    const Text(
                      "Last updated: February 21, 2026",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// Sections of Terms
                    buildSection(
                      "1. Acceptance of Terms",
                      "By accessing and using ExpenseAI, you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to these terms, please do not use our service.",
                    ),

                    buildSection(
                      "2. Use License",
                      "We grant you a limited, non-exclusive, non-transferable license to use ExpenseAI for personal or business expense tracking purposes. You may not modify, distribute, or reverse engineer any part of our application.",
                    ),

                    /// Section with bullet points
                    buildSectionWithList(
                      "3. User Accounts",
                      [
                        "Provide accurate and complete information",
                        "Maintain the security of your password",
                        "Notify us immediately of any unauthorized access",
                        "Be responsible for all activities under your account",
                      ],
                    ),

                    buildSection(
                      "4. AI Services",
                      "Our AI-powered features, including voice recognition and receipt scanning, are provided \"as is\". While we strive for accuracy, we cannot guarantee 100% accuracy in expense categorization or data extraction. You are responsible for verifying all transactions.",
                    ),

                    /// Prohibited uses list
                    buildSectionWithList(
                      "5. Prohibited Uses",
                      [
                        "Violate any laws or regulations",
                        "Infringe on intellectual property rights",
                        "Transmit malicious code or viruses",
                        "Attempt to gain unauthorized access to our systems",
                        "Use automated systems to access the service",
                      ],
                    ),

                    buildSection(
                      "6. Service Availability",
                      "We strive to maintain 99.9% uptime but do not guarantee uninterrupted service. We reserve the right to modify or discontinue the service with or without notice.",
                    ),

                    buildSection(
                      "7. Limitation of Liability",
                      "ExpenseAI shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use or inability to use the service.",
                    ),

                    buildSection(
                      "8. Termination",
                      "We may terminate or suspend your account immediately, without prior notice, for any breach of these Terms. Upon termination, your right to use the service will cease immediately.",
                    ),

                    buildSection(
                      "9. Changes to Terms",
                      "We reserve the right to modify these terms at any time. We will notify users of any material changes via email or in-app notification.",
                    ),

                    buildSection(
                      "10. Contact Information",
                      "For questions about these Terms, please contact us at legal@expenseai.com",
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// Section Builder
  Widget buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// Section title
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 8),

          /// Section content
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  /// Section Builder (Bullet List)
  Widget buildSectionWithList(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// Section title
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 8),

          /// Generate bullet points dynamically
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),

              child: Text(
                "• $item",
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}