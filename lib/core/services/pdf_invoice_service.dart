import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ordermate/features/settings/domain/models/pdf_settings.dart'; // Import Settings
import 'package:number_to_character/number_to_character.dart';

// DTO for passing data to isolate
class InvoiceData {
  final Order order;
  final List<Map<String, dynamic>> items;
  final BusinessPartner customer;
  final String? organizationName;
  final String? storeName;
  final String? storeAddress;
  final String? storePhone;
  final String? customerAddressOverride;
  final Uint8List? logoBytes;
  final PdfSettings settings;
  final String currencyCode;

  final ByteData? regularFontData;
  final ByteData? boldFontData;
  final ByteData? arabicFontData;
  final ByteData? arabicBoldFontData;

  InvoiceData({
    required this.order,
    required this.items,
    required this.customer,
    this.organizationName,
    this.storeName,
    this.storeAddress,
    this.storePhone,
    this.customerAddressOverride,
    this.logoBytes,
    required this.settings,
    required this.currencyCode,
    this.regularFontData,
    this.boldFontData,
    this.arabicFontData,
    this.arabicBoldFontData,
  });
}

// Top-level function for compute
Future<Uint8List> _generatePdf(InvoiceData data) async {
  final pdf = pw.Document();

  // Reconstruct Fonts from ByteData
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

  // Helper Functions reused
  bool hasArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  // Formatter
  final currencySymbol =
      data.settings.showCurrencySymbol ? data.currencyCode : '';
  String formatMoney(double amount) {
    if (!data.settings.enableNumberFormatting) {
      return '${data.settings.showCurrencySymbol ? "$currencySymbol " : ""}${amount.toString()}';
    }
    final formatter = NumberFormat.currency(
        symbol: currencySymbol,
        decimalDigits: data.settings.showDecimals ? 2 : 0,
        customPattern:
            data.settings.showCurrencySymbol ? '\u00A4 #,##0.00' : '#,##0.00');
    // Replace non-breaking space with regular space to avoid Helvetica warnings
    return formatter.format(amount).replaceAll('\u00A0', ' ');
  }

  // Builders inside isolate
  pw.Widget buildInfoRow(
      String label, String value, List<pw.Font> fb, List<pw.Font> fbBold) {
    final isRtl = hasArabic(value);
    // Sanitize value for NBSP
    final sanitizedValue = value.replaceAll('\u00A0', ' ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    fontFallback: fbBold)),
          ),
          pw.Expanded(
            child: pw.Text(
              sanitizedValue,
              style: pw.TextStyle(fontSize: 10, fontFallback: fb),
              textDirection:
                  isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget buildOrderInfo() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final isInvoice =
        data.order.orderNumber.contains('INV') || data.order.id.contains('inv');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(isInvoice ? 'Invoice Information' : 'Order Information',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontFallback: fallbacksBold)),
        pw.SizedBox(height: 4),
        buildInfoRow(
            'Type:',
            data.order.orderType == 'SO'
                ? 'Sales Order'
                : (data.order.orderType == 'SI'
                    ? 'Sales Invoice'
                    : 'Purchase Order'),
            fallbacks,
            fallbacksBold),
        buildInfoRow(isInvoice ? 'Invoice No:' : 'Order No:',
            data.order.orderNumber, fallbacks, fallbacksBold),
        buildInfoRow('Date:', dateFormat.format(data.order.orderDate),
            fallbacks, fallbacksBold),
        if (data.order.sYear != null)
          buildInfoRow('Financial Year:', data.order.sYear.toString(),
              fallbacks, fallbacksBold),
        buildInfoRow('Sales Person:', data.order.createdByName ?? 'Unknown',
            fallbacks, fallbacksBold),
      ],
    );
  }

  pw.Widget buildCustomerInfo() {
    final cAddress = data.customerAddressOverride ?? data.customer.address;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Customer Details',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontFallback: fallbacksBold)),
        pw.SizedBox(height: 4),
        buildInfoRow('Name:', data.customer.name, fallbacks, fallbacksBold),
        if (data.customer.contactPerson != null &&
            data.customer.contactPerson!.isNotEmpty)
          buildInfoRow('Contact Person:', data.customer.contactPerson!,
              fallbacks, fallbacksBold),
        if (data.settings.showAddress)
          buildInfoRow('Address:', cAddress, fallbacks, fallbacksBold),
        if (data.settings.showPhone)
          buildInfoRow('Phone:', data.customer.phone, fallbacks, fallbacksBold),
      ],
    );
  }

  pw.Widget buildTable() {
    final headers = [
      if (data.settings.showSrNumber) 'Sr#',
      'Product',
      'Qty',
      'Price',
      'Discount',
      'Total'
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data.items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        final name = item['product_name'] ?? 'Item';
        final uom = item['uom_symbol'] != null ? ' ${item['uom_symbol']}' : '';
        final qty = '${item['quantity'] ?? 0}$uom';
        final price = formatMoney((item['rate'] as num?)?.toDouble() ?? 0.0);
        final discount =
            formatMoney((item['discount'] as num?)?.toDouble() ?? 0.0);
        final total = formatMoney((item['total'] as num?)?.toDouble() ?? 0.0);

        return [
          if (data.settings.showSrNumber) index.toString(),
          name,
          qty,
          price,
          discount,
          total,
        ];
      }).toList(),
      border: null,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontFallback: fallbacksBold),
      cellStyle: pw.TextStyle(fontFallback: fallbacks),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellHeight: 25,
      cellAlignments: {
        0: data.settings.showSrNumber
            ? pw.Alignment.centerLeft
            : pw.Alignment.centerLeft,
        1: data.settings.showSrNumber
            ? pw.Alignment.centerLeft
            : pw.Alignment.centerRight,
        2: data.settings.showSrNumber
            ? pw.Alignment.centerRight
            : pw.Alignment.centerRight,
        3: data.settings.showSrNumber
            ? pw.Alignment.centerRight
            : pw.Alignment.centerRight,
        4: data.settings.showSrNumber
            ? pw.Alignment.centerRight
            : pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget buildSummaryRow(String label, String value, {bool isBold = false}) {
    final style = isBold
        ? pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            fontFallback: fallbacksBold)
        : pw.TextStyle(fontSize: 12, fontFallback: fallbacks);
    final isRtl = hasArabic(value);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value,
              style: style,
              textDirection:
                  isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr),
        ],
      ),
    );
  }

  pw.Widget buildSummary() {
    final total = data.order.totalAmount;
    final discount = data.items.fold(0.0,
        (sum, item) => sum + ((item['discount'] as num?)?.toDouble() ?? 0.0));
    final gross = total + discount;

    final converter = NumberToCharacterConverter('en');
    final amountWords = data.settings.showAmountInWords
        ? converter.convertInt(total.toInt()).toUpperCase()
        : '';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (data.settings.showAmountInWords)
          pw.Expanded(
              child: pw.Container(
                  margin: const pw.EdgeInsets.only(right: 20),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Amount in Words:',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                fontFallback: fallbacks)),
                        pw.SizedBox(height: 2),
                        pw.Text('$amountWords ONLY',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                fontFallback: fallbacks)),
                      ])))
        else
          pw.Spacer(),
        pw.Container(
          width: 200,
          child: pw.Column(
            children: [
              buildSummaryRow('Gross Total:', formatMoney(gross)),
              buildSummaryRow('Less: Discount:', formatMoney(discount)),
              pw.Divider(),
              buildSummaryRow('Net Total Amount:', formatMoney(total),
                  isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget buildTopRightStack(
      pw.Widget? store, pw.Widget? address, pw.Widget? phone) {
    List<pw.Widget> children = [];
    if (data.settings.storeNamePosition == 'right_invoice' && store != null) {
      children.add(store);
      if (data.settings.addressPosition == 'below_store' && address != null) {
        children.add(address);
        if (data.settings.phonePosition == 'below_address' && phone != null) {
          children.add(phone);
        }
      }
    }
    if (data.settings.addressPosition == 'top_right' && address != null) {
      children.add(address);
      if (data.settings.phonePosition == 'below_address' && phone != null) {
        children.add(phone);
      }
    }
    if (data.settings.phonePosition == 'top_right' && phone != null) {
      children.add(phone);
    }
    if (children.isEmpty) return pw.Container();
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end, children: children);
  }

  List<pw.Widget> space(List<pw.Widget> widgets) {
    if (widgets.isEmpty) return [];
    List<pw.Widget> spaced = [];
    for (var w in widgets) {
      spaced.add(w);
      spaced.add(pw.SizedBox(height: 5));
    }
    return spaced;
  }

  pw.Widget buildFlexibleHeader() {
    final orgName = data.organizationName ?? 'Organization';
    final sName = data.storeName ?? 'Main Office';
    final sAddress = data.storeAddress ?? 'Dubai, UAE';
    final sPhone = data.storePhone ?? '';

    final pw.Widget? logoWidget =
        (data.settings.showLogo && data.logoBytes != null)
            ? pw.Image(pw.MemoryImage(data.logoBytes!), width: 80, height: 80)
            : null;

    final pw.Widget? orgWidget = data.settings.showOrgName
        ? pw.Text(orgName,
            style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                fontFallback: fallbacksBold))
        : null;

    final pw.Widget? storeWidget = data.settings.showStoreName
        ? pw.Text(sName,
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                fontFallback: fallbacksBold))
        : null;

    final pw.Widget? addressWidget = data.settings.showAddress
        ? pw.Text(sAddress,
            style: pw.TextStyle(fontSize: 12, fontFallback: fallbacks))
        : null;

    final pw.Widget? phoneWidget = data.settings.showPhone
        ? pw.Text('Phone: $sPhone',
            style: pw.TextStyle(fontSize: 12, fontFallback: fallbacks))
        : null;

    List<pw.Widget> addressChildren = [];
    if (addressWidget != null) addressChildren.add(addressWidget);
    if (data.settings.phonePosition == 'below_address' && phoneWidget != null) {
      addressChildren.add(phoneWidget);
    }
    final pw.Widget? addressBlock = addressChildren.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: addressChildren)
        : null;

    List<pw.Widget> storeChildren = [];
    if (storeWidget != null) storeChildren.add(storeWidget);
    if (data.settings.addressPosition == 'below_store' && addressBlock != null) {
      storeChildren.add(addressBlock);
    }
    final pw.Widget? storeBlock = storeChildren.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: storeChildren)
        : null;

    List<pw.Widget> orgChildren = [];
    if (orgWidget != null) orgChildren.add(orgWidget);
    if (data.settings.storeNamePosition == 'below_org' && storeBlock != null) {
      orgChildren.add(storeBlock);
    }
    final pw.Widget? orgBlock = orgChildren.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: orgChildren)
        : null;

    if (data.settings.logoPosition == 'left' &&
        data.settings.orgNamePosition == 'after_logo') {
      return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (logoWidget != null) ...[
          logoWidget,
          pw.SizedBox(width: 20),
        ],
        if (orgBlock != null) pw.Expanded(child: orgBlock),
        buildTopRightStack(storeWidget, addressWidget, phoneWidget),
      ]);
    }

    List<pw.Widget> leftCol = [];
    List<pw.Widget> centerCol = [];
    List<pw.Widget> rightCol = [];

    void addToKey(String pos, pw.Widget? w) {
      if (w == null) return;
      if (pos == 'left') {
        leftCol.add(w);
      } else if (pos == 'center') {
        centerCol.add(w);
      } else if (pos == 'right') {
        rightCol.add(w);
      }
    }

    addToKey(data.settings.logoPosition, logoWidget);

    if (data.settings.orgNamePosition == 'after_logo' ||
        data.settings.orgNamePosition == 'right_of_logo') {
      addToKey(data.settings.logoPosition, orgBlock);
    } else if (data.settings.orgNamePosition == 'below_logo') {
      addToKey(data.settings.logoPosition, orgBlock);
    } else {
      addToKey(data.settings.orgNamePosition, orgBlock);
    }

    if (data.settings.storeNamePosition == 'right_invoice') {
      addToKey('right', storeWidget);
      if (data.settings.addressPosition == 'below_store') {
        addToKey('right', addressBlock);
      }
    }

    if (data.settings.addressPosition == 'top_right') {
      addToKey('right', addressBlock);
    }

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (leftCol.isNotEmpty)
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: space(leftCol))),
      if (centerCol.isNotEmpty)
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: space(centerCol))),
      if (rightCol.isNotEmpty)
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: space(rightCol))),
    ]);
  }

  // --- Document Build ---
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
      build: (pw.Context context) {
        return [
          buildFlexibleHeader(),
          if (data.settings.topNote.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(data.settings.topNote,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontFallback: fallbacks)),
          ],
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: buildOrderInfo()),
              pw.SizedBox(width: 20),
              pw.Expanded(child: buildCustomerInfo()),
            ],
          ),
          pw.SizedBox(height: 20),
          buildTable(),
          pw.SizedBox(height: 20),
          buildSummary(),
          if (data.settings.bottomNote.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(data.settings.bottomNote,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontFallback: fallbacks)),
          ],
          pw.SizedBox(height: 40),
          if (data.settings.footerNote.isNotEmpty) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey)),
              child: pw.Text(
                data.settings.footerNote,
                style: pw.TextStyle(fontSize: 9, fontFallback: fallbacks),
                textDirection: hasArabic(data.settings.footerNote)
                    ? pw.TextDirection.rtl
                    : pw.TextDirection.ltr,
              ),
            ),
            pw.SizedBox(height: 10),
          ],
          pw.Center(
            child: pw.Text(
              'generated by Computer no need to sign',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}

class PdfInvoiceService {
  static ByteData? _cachedRegularData;
  static ByteData? _cachedBoldData;
  static ByteData? _cachedArabicData;
  static ByteData? _cachedArabicBoldData;

  // Flags to prevent repeated failed fetch attempts
  static bool _attemptedRegular = false;
  static bool _attemptedBold = false;

  Future<Uint8List> generateInvoice({
    required Order order,
    required List<Map<String, dynamic>> items,
    required BusinessPartner customer,
    String? organizationName,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? customerAddressOverride,
    Uint8List? logoBytes,
    PdfSettings settings = const PdfSettings(),
    String currencyCode = 'AED',
    Function(String message, double progress)? onProgress,
  }) async {
    // 1. Fetch Fonts (Main Thread)
    onProgress?.call('Initializing resources...', 0.3);

    // On Web, manually fetch fonts to support Unicode without AssetManifest errors
    if (kIsWeb) {
      try {
        if (_cachedRegularData == null && !_attemptedRegular) {
          _attemptedRegular = true;
          onProgress?.call('Loading fonts (Regular)...', 0.4);
          debugPrint('PdfInvoiceService: Fetching Regular Font...');
          // Use raw.githubusercontent.com for reliable access
          final response = await http
              .get(Uri.parse(
                  'https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans-Regular.ttf'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            _cachedRegularData = ByteData.view(response.bodyBytes.buffer);
            debugPrint('PdfInvoiceService: Regular Font Fetched Success');
          } else {
            debugPrint(
                'PdfInvoiceService: Regular Font Fetch Failed: ${response.statusCode}');
          }
        }

        if (_cachedBoldData == null && !_attemptedBold) {
          _attemptedBold = true;
          onProgress?.call('Loading fonts (Bold)...', 0.5);
          debugPrint('PdfInvoiceService: Fetching Bold Font...');
          final response = await http
              .get(Uri.parse(
                  'https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans-Bold.ttf'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            _cachedBoldData = ByteData.view(response.bodyBytes.buffer);
            debugPrint('PdfInvoiceService: Bold Font Fetched Success');
          } else {
            debugPrint(
                'PdfInvoiceService: Bold Font Fetch Failed: ${response.statusCode}');
          }
        }
      } catch (e) {
        debugPrint('Web Font Load Error: $e');
        // Fallback to null (Helvetica) happens in _generatePdf
      }
    } else {
      // Native: Use PdfGoogleFonts
      try {
        if (_cachedRegularData == null) {
          try {
            onProgress?.call('Loading fonts...', 0.4);
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
            onProgress?.call('Loading Arabic fonts...', 0.5);
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
        // Ignore font errors
      }
    }

    onProgress?.call('Generating PDF...', 0.7);

    // 2. Prepare Data DTO
    final data = InvoiceData(
      order: order,
      items: items,
      customer: customer,
      organizationName: organizationName,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      customerAddressOverride: customerAddressOverride,
      logoBytes: logoBytes,
      settings: settings,
      currencyCode: currencyCode,
      regularFontData: _cachedRegularData,
      boldFontData: _cachedBoldData,
      arabicFontData: _cachedArabicData,
      arabicBoldFontData: _cachedArabicBoldData,
    );

    // 3. Compute in Background Isolate (Native) or Direct (Web)
    Uint8List result;
    if (kIsWeb) {
      // Web Workers often lack full asset context or fail with plugins.
      // We run directly here.
      result = await _generatePdf(data);
    } else {
      result = await compute(_generatePdf, data);
    }

    onProgress?.call('Finalizing...', 1.0);
    return result;
  }
}
