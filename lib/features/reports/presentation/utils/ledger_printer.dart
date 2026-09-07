import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LedgerPrinter {
  static Future<void> printLedger({
    required String entityName,
    required DateTime startDate,
    required DateTime endDate,
    required double openingBalance,
    required List<Map<String, dynamic>> transactions,
    String? organizationName,
    bool invertBalance = false,
    List<Map<String, dynamic>>? agingInvoices,
  }) async {
    final pdfBytes = await _generateLedgerPdf(
      entityName: entityName,
      startDate: startDate,
      endDate: endDate,
      openingBalance: openingBalance,
      transactions: transactions,
      organizationName: organizationName,
      invertBalance: invertBalance,
      agingInvoices: agingInvoices,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name:
          'Ledger_${entityName}_${DateFormat('yyyyMMdd').format(startDate)}.pdf',
    );
  }

  static Future<Uint8List> _generateLedgerPdf({
    required String entityName,
    required DateTime startDate,
    required DateTime endDate,
    required double openingBalance,
    required List<Map<String, dynamic>> transactions,
    String? organizationName,
    required bool invertBalance,
    List<Map<String, dynamic>>? agingInvoices,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MMM-yyyy');
    final amtFormat = NumberFormat("#,##0.00", "en_US");

    // Retrieve fonts - generic fallback for now to ensure speed/offline compat
    // ideally we reuse the cached fonts from PdfInvoiceService or similar
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          return [
            // Header
            pw.Header(
                level: 0,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(organizationName ?? 'Organization',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 18)),
                            pw.Text('LEDGER REPORT',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 14)),
                          ]),
                      pw.SizedBox(height: 5),
                      pw.Text('Account: $entityName',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text(
                          'Period: ${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey700)),
                    ])),
            pw.SizedBox(height: 10),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(65), // Date
                1: const pw.FixedColumnWidth(70), // Voucher
                2: const pw.FlexColumnWidth(2), // Description
                3: const pw.FixedColumnWidth(60), // Debit
                4: const pw.FixedColumnWidth(60), // Credit
                5: const pw.FixedColumnWidth(70), // Balance
              },
              children: [
                // Header Row
                pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Date', isBold: true),
                      _cell('Voucher #', isBold: true),
                      _cell('Particulars', isBold: true),
                      _cell('Debit', isBold: true, align: pw.TextAlign.right),
                      _cell('Credit', isBold: true, align: pw.TextAlign.right),
                      _cell('Balance', isBold: true, align: pw.TextAlign.right),
                    ]),
                // Opening Balance Row
                pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _cell(dateFormat.format(startDate)),
                      _cell(''),
                      _cell('OPENING BALANCE', isBold: true),
                      _cell(''),
                      _cell(''),
                      _cell(
                          amtFormat.format(
                              invertBalance ? -openingBalance : openingBalance),
                          isBold: true,
                          align: pw.TextAlign.right),
                    ]),
                // Transactions
                ...transactions.map((tx) {
                  final date = DateTime.fromMillisecondsSinceEpoch(
                      tx['voucher_date'] as int);
                  final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
                  final credit = (tx['credit'] as num?)?.toDouble() ?? 0.0;

                  double balance =
                      (tx['running_sum'] as num?)?.toDouble() ?? 0.0;
                  balance += openingBalance;
                  if (invertBalance) balance = -balance;

                  final acName = tx['acname'] ?? '';
                  final desc = tx['description']?.toString() ?? '';
                  final finalDesc = desc.isNotEmpty ? '$acName\n$desc' : acName;

                  return pw.TableRow(children: [
                    _cell(dateFormat.format(date)),
                    _cell(tx['voucher_number']?.toString() ?? '-'),
                    _cell(finalDesc),
                    _cell(debit > 0 ? amtFormat.format(debit) : '',
                        align: pw.TextAlign.right),
                    _cell(credit > 0 ? amtFormat.format(credit) : '',
                        align: pw.TextAlign.right),
                    _cell(amtFormat.format(balance),
                        align: pw.TextAlign.right, isBold: false),
                  ]);
                }),
                // Closing Total (Optional visuals)
              ],
            ),

            if (agingInvoices != null && agingInvoices.isNotEmpty) ...[
              pw.SizedBox(height: 25),
              pw.Text('CUSTOMER AGING (OUTSTANDING BREAKDOWN)',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 10),
              _buildAgingTable(agingInvoices, amtFormat, fontBold),
            ],

            pw.SizedBox(height: 20),
            pw.Footer(
              leading: pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              trailing: pw.Text('Generated by OrderMate',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _cell(String text,
      {bool isBold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 8),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildAgingTable(List<Map<String, dynamic>> invoices,
      NumberFormat amtFormat, pw.Font fontBold) {
    Map<String, List<Map<String, dynamic>>> agingBreakdown = {
      '1 - 30': [],
      '31 - 60': [],
      '61 - 90': [],
      '91 - 120': [],
      '> 120': [],
    };
    Map<String, double> agingTotals = {
      '1 - 30': 0,
      '31 - 60': 0,
      '61 - 90': 0,
      '91 - 120': 0,
      '> 120': 0,
    };

    final now = DateTime.now();

    for (var inv in invoices) {
      final amount = (inv['outstanding_amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) continue;

      final dateStr = inv['invoice_date']?.toString() ?? '';
      DateTime? date;
      if (dateStr.isNotEmpty) {
        if (int.tryParse(dateStr) != null) {
          date = DateTime.fromMillisecondsSinceEpoch(int.parse(dateStr));
        } else {
          date = DateTime.tryParse(dateStr);
        }
      }
      date ??= now;

      final days = now.difference(date).inDays;
      String bucket;
      if (days <= 30) {
        bucket = '1 - 30';
      } else if (days <= 60) {
        bucket = '31 - 60';
      } else if (days <= 90) {
        bucket = '61 - 90';
      } else if (days <= 120) {
        bucket = '91 - 120';
      } else {
        bucket = '> 120';
      }

      agingTotals[bucket] = (agingTotals[bucket] ?? 0) + amount;
      agingBreakdown[bucket]!.add({...inv, 'overdue_days': days, 'date': date});
    }

    final activeBuckets = agingBreakdown.keys
        .where((b) => agingBreakdown[b]!.isNotEmpty)
        .toList();
    if (activeBuckets.isEmpty) return pw.Container();

    return pw.Container(
        decoration:
            pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: activeBuckets.map((bucket) {
            final list = agingBreakdown[bucket]!;
            final total = agingTotals[bucket]!;

            return pw.Expanded(
                child: pw.Container(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(
                            left: pw.BorderSide(color: PdfColors.grey300))),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(bucket,
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9,
                                  color: PdfColors.indigo)),
                          pw.Divider(height: 10, color: PdfColors.grey200),
                          ...list.map((inv) {
                            final days = inv['overdue_days'];
                            final date = inv['date'] as DateTime;
                            return pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 6),
                                child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Row(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text(
                                                inv['invoice_number']
                                                        ?.toString() ??
                                                    'N/A',
                                                style: pw.TextStyle(
                                                    fontWeight:
                                                        pw.FontWeight.bold,
                                                    fontSize: 8)),
                                            pw.Text(
                                                "${DateFormat('MMM dd').format(date)} ($days d)",
                                                style: const pw.TextStyle(
                                                    fontSize: 6,
                                                    color: PdfColors.grey600)),
                                          ]),
                                      pw.Text(
                                          amtFormat.format(
                                              inv['outstanding_amount']),
                                          style: const pw.TextStyle(
                                              fontSize: 8,
                                              color: PdfColors.grey800)),
                                    ]));
                          }),
                          pw.SizedBox(height: 8),
                          pw.Divider(height: 4, color: PdfColors.grey400),
                          pw.SizedBox(height: 4),
                          pw.Text('Total: ${amtFormat.format(total)}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ])));
          }).toList(),
        ));
  }
}
