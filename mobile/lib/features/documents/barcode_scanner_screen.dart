import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Ürün etiketindeki barkodu/QR kodu okutup, doğrudan ilgili dokümanı
/// bulmaya çalışır — sahada model adını elle aramaya gerek kalmaz.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final Dio _dio = ApiClient().dio;
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _lastCode;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code == _lastCode) return;
    _lastCode = code;
    setState(() => _processing = true);
    await _controller.stop();

    try {
      final res = await _dio.get('/search', queryParameters: {'q': code});
      final documents = (res.data['documents'] as List?) ?? [];
      if (!mounted) return;

      if (documents.isEmpty) {
        _showNoResultDialog(code);
      } else if (documents.length == 1) {
        context.pop();
        context.push('/documents/${documents[0]['id']}');
      } else {
        _showResultsList(documents);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showNoResultDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sonuç Bulunamadı'),
        content: Text('"$code" ile eşleşen bir doküman bulunamadı.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            child: const Text('Tekrar Tara'),
          ),
        ],
      ),
    );
  }

  void _showResultsList(List documents) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: documents
              .map((d) => ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.navy),
                    title: Text(d['title'] ?? ''),
                    subtitle: Text('${d['brand']} / ${d['model']}'),
                    onTap: () {
                      Navigator.pop(context); // bottom sheet
                      context.pop(); // scanner ekranı
                      context.push('/documents/${d['id']}');
                    },
                  ))
              .toList(),
        ),
      ),
    ).then((_) => _resumeScanning());
  }

  void _resumeScanning() {
    _lastCode = null;
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod/QR ile Doküman Bul'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _controller.toggleTorch()),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_processing)
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Text(
              'Ürün etiketindeki barkodu/QR kodu çerçeve içine hizalayın',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(blurRadius: 4)]),
            ),
          ),
        ],
      ),
    );
  }
}
