import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ordermate/features/settings/domain/models/pdf_settings.dart';

enum ReportColumnAlignment { left, center, right }

class ReportColumn {
  final String header;
  final String dataKey;
  final ReportColumnAlignment alignment;
  final bool isNumeric;

  const ReportColumn({
    required this.header,
    required this.dataKey,
    this.alignment = ReportColumnAlignment.left,
    this.isNumeric = false,
  });
}

class ReportData {
  final String title;
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> data;
  final PdfSettings settings;
  final String? organizationName;
  final String? storeName;
  final String? storeAddress;
  final String? storePhone;
  final Uint8List? logoBytes;
  final List<String>? totalKeys;

  final ByteData? regularFontData;
  final ByteData? boldFontData;
  final ByteData? arabicFontData;
  final ByteData? arabicBoldFontData;

  const ReportData({
    required this.title,
    required this.columns,
    required this.data,
    required this.settings,
    this.organizationName,
    this.storeName,
    this.storeAddress,
    this.storePhone,
    this.logoBytes,
    this.totalKeys,
    this.regularFontData,
    this.boldFontData,
    this.arabicFontData,
    this.arabicBoldFontData,
  });
}

Future<Uint8List> _generateReportPdf(ReportData data) async {
  final pdf = pw.Document();

  pw.Font? regularFace;
  pw.Font? boldFace;
  pw.Font? arabicFace;
  pw.Font? arabicBold;

  if (data.regularFontData != null) {
    regularFace = pw.Font.ttf(data.regularFontData!);
  } else {
    regularFace = pw.Font.helvetica();
  }

  if (data.boldFontData != null) {
    boldFace = pw.Font.ttf(data.boldFontData!);
  } else {
    boldFace = pw.Font.helveticaBold();
  }

  if (data.arabicFontData != null) {
    arabicFace = pw.Font.ttf(data.arabicFontData!);
  }
  if (data.arabicBoldFontData != null) {
    arabicBold = pw.Font.ttf(data.arabicBoldFontData!);
  }

  final font = regularFace;
  final fontBold = boldFace;

  final List<pw.Font> fallbacks = [
    if (arabicFace != null) arabicFace,
  ];
  final List<pw.Font> fallbacksBold = [
    if (arabicBold != null) arabicBold,
    if (arabicFace != null) arabicFace,
  ];

  bool hasArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  final currencySymbol =
      data.settings.showCurrencySymbol ? 'USD' : '';
  String formatMoney(double amount) {
    if (!data.settings.enableNumberFormatting) {
      return '${data.settings.showCurrencySymbol ? "$currencySymbol " : ""}${amount.toString()}';
    }
    final formatter = NumberFormat.currency(
        symbol: currencySymbol,
        decimalDigits: data.settings.showDecimals ? 2 : 0,
        customPattern:
            data.settings.showCurrencySymbol ? '\u00A4 #,##0.00' : '#,##0.00');
    return formatter.format(amount).replaceAll('\u00A0', ' ');
  }

  pw.Widget buildHeader() {
    final orgName = data.organizationName ?? 'Organization';
    final sName = data.storeName ?? 'Store';
    final sAddress = data.storeAddress ?? '';
    final sPhone = data.storePhone ?? '';

    final pw.Widget? logoWidget =
        (data.settings.showLogo && data.logoBytes != null)
            ? pw.Image(pw.MemoryImage(data.logoBytes!), width: 70, height: 70)
            : null;

    final pw.Widget? orgWidget = data.settings.showOrgName
        ? pw.Text(orgName,
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                fontFallback: fallbacksBold))
        : null;

    final pw.Widget? storeWidget = data.settings.showStoreName
        ? pw.Text(sName,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                fontFallback: fallbacksBold))
        : null;

    final pw.Widget? addressWidget = data.settings.showAddress && sAddress.isNotEmpty
        ? pw.Text(sAddress,
            style: pw.TextStyle(fontSize: 10, fontFallback: fallbacks))
        : null;

    final pw.Widget? phoneWidget = data.settings.showPhone && sPhone.isNotEmpty
        ? pw.Text('Phone: $sPhone',
            style: pw.TextStyle(fontSize: 10, fontFallback: fallbacks))
        : null;

    List<pw.Widget> children = [];
    if (logoWidget != null) children.add(logoWidget);
    if (orgWidget != null) children.add(orgWidget);
    if (storeWidget != null) children.add(storeWidget);
    if (addressWidget != null) children.add(addressWidget);
    if (phoneWidget != null) children.add(phoneWidget);

    if (children.isEmpty) return pw.Container();

    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
  }

  pw.Widget buildTable() {
    final headers = data.columns.map((c) => c.header).toList();
    final tableData = data.data.map((row) {
      return data.columns.map((col) {
        final raw = row[col.dataKey];
        if (raw == null) return '';
        if (col.isNumeric && raw is num) {
          return formatMoney(raw.toDouble());
        }
        return raw.toString();
      }).toList();
    }).toList();

    final cellAlignments = <int, pw.Alignment>{};
    for (int i = 0; i < data.columns.length; i++) {
      final col = data.columns[i];
      switch (col.alignment) {
        case ReportColumnAlignment.left:
          cellAlignments[i] = pw.Alignment.centerLeft;
          break;
        case ReportColumnAlignment.center:
          cellAlignments[i] = pw.Alignment.center;
          break;
        case ReportColumnAlignment.right:
          cellAlignments[i] = pw.Alignment.centerRight;
          break;
      }
    }

    final List<List<String>> allRows = [headers, ...tableData];

    if (data.totalKeys != null && data.totalKeys!.isNotEmpty) {
      final totalsRow = List<String>.filled(data.columns.length, '');
      for (int i = 0; i < data.columns.length; i++) {
        final col = data.columns[i];
        if (col.isNumeric && data.totalKeys!.contains(col.dataKey)) {
          double sum = 0.0;
          for (final row in data.data) {
            final val = row[col.dataKey];
            if (val is num) sum += val.toDouble();
          }
          totalsRow[i] = formatMoney(sum);
        }
      }
      allRows.add(totalsRow);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: allRows.length > 1 ? allRows.sublist(1) : [],
      border: null,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontFallback: fallbacksBold),
      cellStyle: pw.TextStyle(fontFallback: fallbacks),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellHeight: 22,
      cellAlignments: cellAlignments,
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.only(
        top: data.settings.marginTop * 2.83,
        bottom: data.settings.marginBottom * 2.83,
        left: 40,
        right: 40,
      ),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      header: (context) {
        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: buildHeader(),
        );
      },
      footer: (context) {
        return pw.Column(
          children: [
            if (data.settings.footerNote.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey)),
                child: pw.Text(
                  data.settings.footerNote,
                  style: pw.TextStyle(fontSize: 8, fontFallback: fallbacks),
                  textDirection: hasArabic(data.settings.footerNote)
                      ? pw.TextDirection.rtl
                      : pw.TextDirection.ltr,
                ),
              ),
              pw.SizedBox(height: 6),
            ],
            pw.Center(
              child: pw.Text(
                'generated by Computer no need to sign',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ],
        );
      },
      build: (pw.Context context) {
        return [
          pw.Text(data.title,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: fallbacksBold)),
          pw.SizedBox(height: 10),
          buildTable(),
        ];
      },
    ),
  );

  return pdf.save();
}

class PdfReportService {
  static ByteData? _cachedRegularData;
  static ByteData? _cachedBoldData;
  static ByteData? _cachedArabicData;
  static ByteData? _cachedArabicBoldData;
  static bool _attemptedRegular = false;
  static bool _attemptedBold = false;

  Future<Uint8List> generateReport({
    required String title,
    required List<ReportColumn> columns,
    required List<Map<String, dynamic>> data,
    required PdfSettings settings,
    String? organizationName,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    Uint8List? logoBytes,
    List<String>? totalKeys,
  }) async {
    if (kIsWeb) {
      try {
        if (_cachedRegularData == null && !_attemptedRegular) {
          _attemptedRegular = true;
          final response = await http
              .get(Uri.parse(
                  'https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans-Regular.ttf'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            _cachedRegularData = ByteData.view(response.bodyBytes.buffer);
          }
        }
        if (_cachedBoldData == null && !_attemptedBold) {
          _attemptedBold = true;
          final response = await http
              .get(Uri.parse(
                  'https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans-Bold.ttf'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            _cachedBoldData = ByteData.view(response.bodyBytes.buffer);
          }
        }
      } catch (e) {
        debugPrint('Web Font Load Error: $e');
      }
    } else {
      try {
        if (_cachedRegularData == null) {
          try {
            final f = await PdfGoogleFonts.notoSansRegular()
                .timeout(const Duration(seconds: 3));
            _cachedRegularData = (f as pw.TtfFont).data;
          } catch (_) {}
        }
        if (_cachedBoldData == null) {
          try {
            final f = await PdfGoogleFonts.notoSansBold()
                .timeout(const Duration(seconds: 3));
            _cachedBoldData = (f as pw.TtfFont).data;
          } catch (_) {}
        }
        if (_cachedArabicData == null) {
          try {
            final f = await PdfGoogleFonts.notoSansArabicRegular()
                .timeout(const Duration(seconds: 3));
            _cachedArabicData = (f as pw.TtfFont).data;
            final fB = await PdfGoogleFonts.notoSansArabicBold()
                .timeout(const Duration(seconds: 3));
            _cachedArabicBoldData = (fB as pw.TtfFont).data;
          } catch (_) {
            try {
              final f = await PdfGoogleFonts.amiriRegular()
                  .timeout(const Duration(seconds: 3));
              _cachedArabicData = (f as pw.TtfFont).data;
              final fB = await PdfGoogleFonts.amiriBold()
                  .timeout(const Duration(seconds: 3));
              _cachedArabicBoldData = (fB as pw.TtfFont).data;
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Font Load Error: $e');
      }
    }

    final reportData = ReportData(
      title: title,
      columns: columns,
      data: data,
      settings: settings,
      organizationName: organizationName,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      logoBytes: logoBytes,
      totalKeys: totalKeys,
      regularFontData: _cachedRegularData,
      boldFontData: _cachedBoldData,
      arabicFontData: _cachedArabicData,
      arabicBoldFontData: _cachedArabicBoldData,
    );

    Uint8List result;
    if (kIsWeb) {
      result = await _generateReportPdf(reportData);
    } else {
      result = await compute(_generateReportPdf, reportData);
    }

    return result;
  }
}
