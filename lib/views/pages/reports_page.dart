import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker_app/services/currency_provider.dart';

// Main page for exporting expense reports
// Supports quick monthly export and custom date range export
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Default custom report date range
  DateTime fromDate = DateTime(2026, 1, 1);
  DateTime toDate = DateTime(2026, 1, 31);

  // Currently selected export format for custom report
  String customFormat = "PDF";

  // Available export format options shown in the UI
  final List<Map<String, String>> formatOptions = [
    {"type": "PDF", "icon": "📄"},
    {"type": "Excel", "icon": "📊"},
  ];

  // Month selected for quick export
  DateTime? selectedMonth;

  @override
  void initState() {
    super.initState();

    // Default to the latest month in the quick export list
    selectedMonth = getLast5Months().first;
  }

  // Convert a DateTime into a readable month label like "April 2026"
  String _formatMonthName(DateTime date) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  // Open date picker for either fromDate or toDate
  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  // Format a DateTime as yyyy-mm-dd
  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Generate a list of the latest 5 months starting from the current month
  List<DateTime> getLast5Months() {
    final now = DateTime.now();
    return List.generate(5, (index) {
      return DateTime(now.year, now.month - index, 1);
    });
  }

  // Read transactions from Firestore within the selected date range
  // Also maps category_id to category name for easier report output
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    // Set to end of selected day so transactions on the toDate are included
    final endOfDay = DateTime(
      toDate.year,
      toDate.month,
      toDate.day,
      23,
      59,
      59,
    );

    // Load all categories first and build a category lookup map
    final categorySnapshot = await firestore.collection("Categories").get();

    Map<String, String> categoryMap = {};
    for (var doc in categorySnapshot.docs) {
      final data = doc.data();
      categoryMap[doc.id] = data["category_name"] ?? "Unknown";
    }

    // Fetch all expense records in the selected range for the current user
    final snapshot = await firestore
        .collection("Expenses")
        .where("uid", isEqualTo: uid)
        .where(
          "expense_date",
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate),
        )
        .where(
          "expense_date",
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
        )
        .orderBy("expense_date")
        .get();

    List<Map<String, dynamic>> transactions = [];

    // Convert raw Firestore documents into a simpler report-friendly structure
    for (var doc in snapshot.docs) {
      final d = doc.data();

      transactions.add({
        "date": (d["expense_date"] as Timestamp).toDate(),
        "category": categoryMap[d["category_id"]] ?? "Unknown",
        "merchant": d["merchant"] ?? "",
        "amount": d["amount"] ?? 0,
      });
    }

    return transactions;
  }

  // Generate PDF report, save it into temporary storage, then share it
  Future<void> generatePDFReport() async {
    try {
      final data = await getTransactions();

      if (!mounted) return;

      // Stop early if there is nothing to export
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No transactions found"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Get current display currency from provider
      final provider = Provider.of<CurrencyProvider>(context, listen: false);
      final currency = provider.currencySymbol;

      final pdf = pw.Document();

      // Convert stored base amounts into the user's selected display currency
      final convertedData = data.map((d) {
        final amount = (d["amount"] as num).toDouble();
        final converted = provider.convert(amount);
        return {...d, "converted": converted};
      }).toList();

      // Calculate report total
      double total = convertedData.fold(
        0,
        (acc, item) => acc + (item["converted"] as double),
      );

      // Build the PDF page
      pdf.addPage(
        pw.Page(
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Expense Report",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text("From: ${formatDate(fromDate)}"),
                pw.Text("To: ${formatDate(toDate)}"),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ["Date", "Category", "Merchant", "Amount"],
                  data: convertedData.map((d) {
                    return [
                      d["date"].toString().split(" ")[0],
                      d["category"],
                      d["merchant"],
                      "$currency ${(d["converted"] as double).toStringAsFixed(2)}",
                    ];
                  }).toList(),
                ),
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "Total: $currency ${total.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save the generated PDF into a temporary file
      final dir = await getTemporaryDirectory();

      final file = File(
        "${dir.path}/expense_report_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );

      await file.create(recursive: true);
      await file.writeAsBytes(await pdf.save());

      // Safety check to ensure the file was actually created
      if (!await file.exists()) {
        debugPrint("ERROR: PDF not created");
        return;
      }

      // Share the generated PDF file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: "Expense Report",
        ),
      );
    } catch (e) {
      debugPrint("PDF ERROR: $e");
    }
  }

  // Generate Excel report, save it into temporary storage, then share it
  Future<void> generateExcelReport() async {
    final data = await getTransactions();

    if (!mounted) return;

    // Stop early if there is nothing to export
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No transactions found"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Get current display currency from provider
    final provider = Provider.of<CurrencyProvider>(context, listen: false);
    final currency = provider.currencySymbol;

    // Create workbook and worksheet
    var excelFile = excel.Excel.createExcel();
    excel.Sheet sheet = excelFile['Report'];

    // Add header row
    sheet.appendRow([
      excel.TextCellValue("Date"),
      excel.TextCellValue("Category"),
      excel.TextCellValue("Merchant"),
      excel.TextCellValue("Amount"),
    ]);

    // Add data rows
    for (var d in data) {
      final amount = (d["amount"] as num).toDouble();
      final converted = provider.convert(amount);

      sheet.appendRow([
        excel.TextCellValue(d["date"].toString().split(" ")[0]),
        excel.TextCellValue(d["category"]),
        excel.TextCellValue(d["merchant"]),
        excel.TextCellValue("$currency ${converted.toStringAsFixed(2)}"),
      ]);
    }

    // Save Excel file into temporary storage
    final dir = await getTemporaryDirectory();

    String filePath =
        "${dir.path}/expense_report_${DateTime.now().millisecondsSinceEpoch}.xlsx";

    File file = File(filePath);

    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(excelFile.encode()!);

    // Share the generated Excel file
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text: "Expense Report",
      ),
    );
  }

  // Main page UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // Top header
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
                  "Reports",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Export and share your expense reports",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Scrollable page content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildQuickExportCard(),
                  const SizedBox(height: 20),
                  _buildCustomReportCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Quick export card for exporting one of the latest 5 months
  Widget _buildQuickExportCard() {
    final months = getLast5Months();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Export",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Select a month, then choose a format to export",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 25),

          const Text(
            "Month",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),

          // Month dropdown
          Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.white),
            child: DropdownButtonFormField<DateTime>(
              initialValue: selectedMonth,
              isDense: true,
              items: months.map((month) {
                return DropdownMenuItem(
                  value: month,
                  child: Text(
                    _formatMonthName(month),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedMonth = value;
                });
              },
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Quick PDF export button
          _buildExportCard(
            title: "Export to PDF",
            color: const Color(0xFFFDECEC),
            borderColor: const Color(0xFFFCA5A5),
            iconBg: const Color(0xFFFEE2E2),
            icon: Icons.description,
            iconColor: Colors.red,
            onTap: () async {
              if (selectedMonth == null) return;

              final start = DateTime(
                selectedMonth!.year,
                selectedMonth!.month,
                1,
              );
              final end = DateTime(
                selectedMonth!.year,
                selectedMonth!.month + 1,
                0,
              );

              // Temporarily switch the date range for export
              DateTime oldFrom = fromDate;
              DateTime oldTo = toDate;

              setState(() {
                fromDate = start;
                toDate = end;
              });

              await generatePDFReport();

              // Restore previous custom range after export
              setState(() {
                fromDate = oldFrom;
                toDate = oldTo;
              });
            },
          ),

          const SizedBox(height: 8),

          // Quick Excel export button
          _buildExportCard(
            title: "Export to Excel",
            color: const Color(0xFFECFDF5),
            borderColor: const Color(0xFF86EFAC),
            iconBg: const Color(0xFFD1FAE5),
            icon: Icons.bar_chart,
            iconColor: Colors.green,
            onTap: () async {
              if (selectedMonth == null) return;

              final start = DateTime(
                selectedMonth!.year,
                selectedMonth!.month,
                1,
              );
              final end = DateTime(
                selectedMonth!.year,
                selectedMonth!.month + 1,
                0,
              );

              // Temporarily switch the date range for export
              DateTime oldFrom = fromDate;
              DateTime oldTo = toDate;

              setState(() {
                fromDate = start;
                toDate = end;
              });

              await generateExcelReport();

              // Restore previous custom range after export
              setState(() {
                fromDate = oldFrom;
                toDate = oldTo;
              });
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Reusable export option card used in the quick export section
  Widget _buildExportCard({
    required String title,
    required Color color,
    required Color borderColor,
    required Color iconBg,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }

  // Custom report card for manually selecting date range and export format
  Widget _buildCustomReportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Custom Report",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Pick a date range and export format",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),

          // Date range fields
          Row(
            children: [
              Expanded(
                child: _dateField(
                  "From Date",
                  formatDate(fromDate),
                  () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField(
                  "To Date",
                  formatDate(toDate),
                  () => _pickDate(false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          const Text(
            "Export Format",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),

          // Format selection buttons
          Row(
            children: formatOptions.map((f) {
              final selected = customFormat == f["type"];

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      customFormat = f["type"]!;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEFF6FF)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(f["icon"]!, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(
                          f["type"]!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Generate custom report button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  if (customFormat == "PDF") {
                    await generatePDFReport();
                  } else {
                    await generateExcelReport();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: Text(
                  "Generate $customFormat Report",
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable date input field used in custom report section
  Widget _dateField(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Shared card decoration for the report sections
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}