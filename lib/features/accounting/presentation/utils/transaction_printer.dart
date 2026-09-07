import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TransactionPrinter {
  static Future<Uint8List> _generatePdf(
    Transaction tx,
    ChartOfAccount? account,
    ChartOfAccount? offsetAccount,
    Organization? org, {
    String? voucherTypeName,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              if (org != null)
                pw.Center(
                  child: pw.Text(org.name,
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                    (voucherTypeName ?? 'TRANSACTION VOUCHER').toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Voucher No: ${tx.voucherNumber}'),
                  pw.Text('Date: ${dateFormat.format(tx.voucherDate)}'),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Status: ${tx.status.toUpperCase()}'),
                  ]),

              pw.SizedBox(height: 30),

              // Account Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Account Title',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Debit',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Credit',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  // Debit (Account)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child:
                              pw.Text(account?.accountTitle ?? tx.accountId)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(currencyFormat.format(tx.amount),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('', textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  // Credit (Offset Account) - Assuming simple double entry where offset is Cr
                  if (offsetAccount != null || tx.offsetAccountId != null)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(offsetAccount?.accountTitle ??
                                tx.offsetAccountId ??
                                '')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('', textAlign: pw.TextAlign.right)),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(currencyFormat.format(tx.amount),
                                textAlign: pw.TextAlign.right)),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 20),

              if (tx.description != null && tx.description!.isNotEmpty) ...[
                pw.Text('Description:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(tx.description!),
                pw.SizedBox(height: 20),
              ],

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 5),
                    pw.Text('Prepared By'),
                  ]),
                  pw.Column(children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 5),
                    pw.Text('Approved By'),
                  ]),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static Future<void> printTransaction({
    required Transaction tx,
    required ChartOfAccount? account,
    required ChartOfAccount? offsetAccount,
    required Organization? org,
    String? voucherTypeName,
  }) async {
    final pdfBytes = await _generatePdf(tx, account, offsetAccount, org,
        voucherTypeName: voucherTypeName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${tx.voucherNumber}.pdf',
    );
  }

  static Future<void> shareTransaction({
    required Transaction tx,
    required ChartOfAccount? account,
    required ChartOfAccount? offsetAccount,
    required Organization? org,
    String? voucherTypeName,
  }) async {
    final pdfBytes = await _generatePdf(tx, account, offsetAccount, org,
        voucherTypeName: voucherTypeName);
    await Printing.sharePdf(
        bytes: pdfBytes, filename: '${tx.voucherNumber}.pdf');
  }
}
