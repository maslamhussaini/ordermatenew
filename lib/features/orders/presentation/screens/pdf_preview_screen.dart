import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    required this.pdfBytes,
    required this.fileName,
    super.key,
  });

  final Uint8List pdfBytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview $fileName')),
      body: pdfBytes.isEmpty
          ? const Center(child: Text('Error: PDF content is empty.'))
          : PdfPreview(
              build: (format) => pdfBytes,
              pdfFileName: fileName,
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              maxPageWidth: 700,
            ),
    );
  }
}
