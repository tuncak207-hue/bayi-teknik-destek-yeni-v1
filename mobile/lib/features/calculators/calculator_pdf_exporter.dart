import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// Bir hesaplama sonucunu, müşteriye sunulabilecek sade bir PDF rapora
/// dönüştürüp cihaza kaydeder ve sistem uygulamasıyla açar. Akü/Kamera
/// HDD/PoE hesaplayıcılarının hepsi bunu kullanır.
class CalculatorPdfExporter {
  static Future<void> export({
    required BuildContext context,
    required String title,
    required Map<String, dynamic> result,
    required Map<String, String> labels,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ENTPA Mühendislik Hizmeti',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  DateTime.now().toString().substring(0, 16),
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                ),
                pw.SizedBox(height: 24),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: result.entries.where((e) => e.key != 'note').map((e) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(labels[e.key] ?? e.key),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${e.value}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                if (result['note'] != null) ...[
                  pw.SizedBox(height: 16),
                  pw.Text(
                    result['note'].toString(),
                    style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                  ),
                ],
                pw.SizedBox(height: 32),
                pw.Divider(color: PdfColors.grey300),
                pw.Text(
                  'Bu rapor Bayi Teknik Destek uygulaması tarafından otomatik oluşturulmuştur.',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey400),
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '');
    final file = File('${dir.path}/$safeTitle.pdf');
    await file.writeAsBytes(bytes);
    await OpenFilex.open(file.path);
  }
}
