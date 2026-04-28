import 'package:flutter/material.dart';

/// Displays the Privacy Policy page of the application
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),

      // Main layout structure: Header + Scrollable Content
      body: Column(
        children: [

          // Top header with gradient background and back navigation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                // Back button to return to previous screen
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(width: 10),

                // Page title
                const Text(
                  "Privacy Policy",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content section containing policy details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),

              // Card-style container for better readability
              child: Container(
                padding: const EdgeInsets.all(20),
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

                    // Display last updated date
                    const Text(
                      "Last updated: February 21, 2026",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),

                    const SizedBox(height: 20),

                    // Policy sections
                    buildSection(
                      "1. Information We Collect",
                      "We collect information you provide directly to us, including your name, email address, phone number, and expense data. We also collect information about your device and how you use our app through analytics and cookies.",
                    ),

                    buildSectionWithList("2. How We Use Your Information", [
                      "Provide, maintain, and improve our services",
                      "Process your expense transactions and generate reports",
                      "Send you technical notices and support messages",
                      "Respond to your comments and questions",
                      "Analyze usage patterns to improve user experience",
                    ]),

                    buildSection(
                      "3. Data Security",
                      "We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. Your data is encrypted both in transit and at rest using industry-standard encryption protocols.",
                    ),

                    buildSection(
                      "4. AI and Voice Processing",
                      "When you use voice input features, your voice recordings are processed using our AI engine to extract expense information. Voice data is processed securely and is not stored after processing is complete, unless you explicitly consent to save recordings for quality improvement.",
                    ),

                    buildSection(
                      "5. Data Sharing",
                      "We do not sell your personal information. We may share your information with third-party service providers who perform services on our behalf, such as cloud hosting and analytics, under strict confidentiality agreements.",
                    ),

                    buildSectionWithList("6. Your Rights", [
                      "Access your personal data",
                      "Correct inaccurate data",
                      "Request deletion of your data",
                      "Export your data in a portable format",
                      "Opt-out of marketing communications",
                    ]),

                    buildSection(
                      "7. Contact Us",
                      "If you have questions about this Privacy Policy, please contact us at privacy@expenseai.com",
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

  /// Builds a section consisting of a title and descriptive paragraph
  Widget buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Section title
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 8),

          // Section content
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

  /// Builds a section with a title and bullet-point list
  Widget buildSectionWithList(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Section title
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 8),

          // Bullet list items
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