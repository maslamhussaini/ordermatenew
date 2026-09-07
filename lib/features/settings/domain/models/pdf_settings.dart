import 'dart:convert';

class PdfSettings {
  final bool showCurrencySymbol;
  final bool showDecimals;
  final bool showOrgName;
  final bool showStoreName;
  final bool showAddress;
  final bool showPhone;
  final bool showLogo;
  final bool showAmountInWords;
  final bool enableNumberFormatting;
  final bool showSrNumber;

  final String topNote;
  final String bottomNote;
  final String footerNote; // "Footer Note _________ textbox"

  // Positioning
  final String logoPosition; // 'left', 'right', 'center'
  // Simplified relative positioning for implementation sanity while meeting requirements
  final String orgNamePosition; // 'left', 'right', 'center', 'right_of_logo'
  final String storeNamePosition; // 'below_org', 'right_of_org', 'center'
  final String addressPosition; // 'below_store', 'top_right'
  final String phonePosition; // 'below_address', 'top_right'

  // Margins (Letterhead support)
  final double marginTop;
  final double marginBottom;

  const PdfSettings({
    this.showCurrencySymbol = true,
    this.showDecimals = true,
    this.showOrgName = true,
    this.showStoreName = true,
    this.showAddress = true,
    this.showPhone = true,
    this.showLogo = true,
    this.showAmountInWords = false,
    this.enableNumberFormatting = true,
    this.showSrNumber = true,
    this.topNote = '',
    this.bottomNote = '',
    this.footerNote = '',
    this.logoPosition = 'left',
    this.orgNamePosition = 'left',
    this.storeNamePosition = 'below_org',
    this.addressPosition = 'below_store',
    this.phonePosition = 'below_address',
    this.marginTop = 10.0,
    this.marginBottom = 10.0,
  });

  PdfSettings copyWith({
    bool? showCurrencySymbol,
    bool? showDecimals,
    bool? showOrgName,
    bool? showStoreName,
    bool? showAddress,
    bool? showPhone,
    bool? showLogo,
    bool? showAmountInWords,
    bool? enableNumberFormatting,
    bool? showSrNumber,
    String? topNote,
    String? bottomNote,
    String? footerNote,
    String? logoPosition,
    String? orgNamePosition,
    String? storeNamePosition,
    String? addressPosition,
    String? phonePosition,
    double? marginTop,
    double? marginBottom,
  }) {
    return PdfSettings(
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
      showDecimals: showDecimals ?? this.showDecimals,
      showOrgName: showOrgName ?? this.showOrgName,
      showStoreName: showStoreName ?? this.showStoreName,
      showAddress: showAddress ?? this.showAddress,
      showPhone: showPhone ?? this.showPhone,
      showLogo: showLogo ?? this.showLogo,
      showAmountInWords: showAmountInWords ?? this.showAmountInWords,
      enableNumberFormatting:
          enableNumberFormatting ?? this.enableNumberFormatting,
      showSrNumber: showSrNumber ?? this.showSrNumber,
      topNote: topNote ?? this.topNote,
      bottomNote: bottomNote ?? this.bottomNote,
      footerNote: footerNote ?? this.footerNote,
      logoPosition: logoPosition ?? this.logoPosition,
      orgNamePosition: orgNamePosition ?? this.orgNamePosition,
      storeNamePosition: storeNamePosition ?? this.storeNamePosition,
      addressPosition: addressPosition ?? this.addressPosition,
      phonePosition: phonePosition ?? this.phonePosition,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showCurrencySymbol': showCurrencySymbol,
      'showDecimals': showDecimals,
      'showOrgName': showOrgName,
      'showStoreName': showStoreName,
      'showAddress': showAddress,
      'showPhone': showPhone,
      'showLogo': showLogo,
      'showAmountInWords': showAmountInWords,
      'enableNumberFormatting': enableNumberFormatting,
      'showSrNumber': showSrNumber,
      'topNote': topNote,
      'bottomNote': bottomNote,
      'footerNote': footerNote,
      'logoPosition': logoPosition,
      'orgNamePosition': orgNamePosition,
      'storeNamePosition': storeNamePosition,
      'addressPosition': addressPosition,
      'phonePosition': phonePosition,
      'marginTop': marginTop,
      'marginBottom': marginBottom,
    };
  }

  factory PdfSettings.fromMap(Map<String, dynamic> map) {
    return PdfSettings(
      showCurrencySymbol: map['showCurrencySymbol'] ?? true,
      showDecimals: map['showDecimals'] ?? true,
      showOrgName: map['showOrgName'] ?? true,
      showStoreName: map['showStoreName'] ?? true,
      showAddress: map['showAddress'] ?? true,
      showPhone: map['showPhone'] ?? true,
      showLogo: map['showLogo'] ?? true,
      showAmountInWords: map['showAmountInWords'] ?? false,
      enableNumberFormatting: map['enableNumberFormatting'] ?? true,
      showSrNumber: map['showSrNumber'] ?? true,
      topNote: map['topNote'] ?? '',
      bottomNote: map['bottomNote'] ?? '',
      footerNote: map['footerNote'] ?? '',
      logoPosition: map['logoPosition'] ?? 'left',
      orgNamePosition: map['orgNamePosition'] ?? 'left',
      storeNamePosition: map['storeNamePosition'] ?? 'below_org',
      addressPosition: map['addressPosition'] ?? 'below_store',
      phonePosition: map['phonePosition'] ?? 'below_address',
      marginTop: map['marginTop']?.toDouble() ?? 10.0,
      marginBottom: map['marginBottom']?.toDouble() ?? 10.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory PdfSettings.fromJson(String source) =>
      PdfSettings.fromMap(json.decode(source));
}
