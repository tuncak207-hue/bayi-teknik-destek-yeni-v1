import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Paylaşılan imza alanı — Bakım ve Devreye Alma formlarının ikisi de
/// aynı bileşeni kullanıyor (kod tekrarını önlemek ve tutarlı görünüm için).
class SignaturePad extends StatefulWidget {
  final ValueChanged<List<Offset?>> onChanged;
  /// Parmak imza alanına değdiğinde true, kalktığında false ile çağrılır.
  /// "Ekranda çizgi oluşuyor" hatasının kök nedeni buydu: bu alan bir
  /// kaydırılabilir ListView'ın içindeydi ve sayfayı kaydırmak için yapılan
  /// her dokunuş, imza alanının üzerinden geçtiğinde YANLIŞLIKLA kısa bir
  /// çizgi olarak kaydediliyordu. Üst ekran bu geri çağrıyı kullanarak,
  /// parmak imza kutusunun içindeyken listenin kaymasını geçici olarak
  /// kapatabilir — böylece kutunun üzerindeki her dokunuş SADECE imza
  /// olarak yorumlanır, kayma ile karışmaz.
  final ValueChanged<bool>? onDrawingChanged;

  const SignaturePad({super.key, required this.onChanged, this.onDrawingChanged});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  List<Offset?> _points = [];

  bool get hasSignature => _points.where((p) => p != null).length > 5;

  void clear() {
    setState(() => _points = []);
    widget.onChanged(_points);
  }

  /// İmzayı PNG bayt dizisine çevirir — backend'e yüklemek için.
  Future<Uint8List?> renderToPng() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(320, 200);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < _points.length - 1; i++) {
      final p1 = _points[i];
      final p2 = _points[i + 1];
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, paint);
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasSignature ? AppColors.brand.withValues(alpha: 0.3) : Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          // ÖNEMLİ DÜZELTME: "imza alanına geçmiyor, imza atamıyorum" —
          // bu bileşen kaydırılabilir bir ListView'in İÇİNDE duruyor.
          // Önceden GestureDetector.onPanUpdate kullanılıyordu — bu,
          // Flutter'ın "gesture arena" (dokunma yarışması) sistemine
          // giriyor ve ListView'ın kendi kaydırma hareketiyle
          // çakışıyordu, çoğu zaman ListView kazanıp imza hiç
          // çizilmiyordu. Listener ile HAM dokunma olayları dinleniyor
          // — bu, üst kaydırma widget'ıyla YARIŞMIYOR, kesin çalışıyor.
          Listener(
            onPointerDown: (event) {
              widget.onDrawingChanged?.call(true);
              final box = context.findRenderObject() as RenderBox?;
              final local = box?.globalToLocal(event.position);
              setState(() => _points = [..._points, local]);
              widget.onChanged(_points);
            },
            onPointerMove: (event) {
              final box = context.findRenderObject() as RenderBox?;
              final local = box?.globalToLocal(event.position);
              setState(() => _points = [..._points, local]);
              widget.onChanged(_points);
            },
            onPointerUp: (_) {
              setState(() => _points = [..._points, null]);
              widget.onChanged(_points);
              widget.onDrawingChanged?.call(false);
            },
            onPointerCancel: (_) {
              widget.onDrawingChanged?.call(false);
            },
            child: CustomPaint(painter: _SignaturePainter(_points), size: Size.infinite),
          ),
          if (_points.isEmpty)
            Center(
              child: Text(
                'Müşteri buraya parmağıyla imza atabilir',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
              ),
            ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navy
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
