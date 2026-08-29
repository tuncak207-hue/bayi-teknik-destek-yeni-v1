import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tek, premium bir e-posta giriş alanı. Önceden bu alan "kullanıcı
/// adı" + "@" + "uzantı" olarak ikiye bölünmüştü (bazı emülatör/klavye
/// sürücülerinde @ tuşu sorunu için) — kullanıcı isteği üzerine tekrar
/// tek alana dönüştürüldü ve tasarımı premium hale getirildi.
///
/// Kullanım: `EmailSplitField(onChanged: (email) => ...)` — geçerli bir
/// e-posta formatı girildiğinde tam e-postayı, aksi halde `null` verir.
/// (Dış API, önceki bölünmüş sürümle aynı — çağıran ekranlarda değişiklik
/// gerekmez.)
class EmailSplitField extends StatefulWidget {
  final ValueChanged<String?> onChanged;
  final String? initialUsername;
  final String? initialDomain;

  const EmailSplitField({
    super.key,
    required this.onChanged,
    this.initialUsername,
    this.initialDomain,
  });

  @override
  State<EmailSplitField> createState() => EmailSplitFieldState();
}

class EmailSplitFieldState extends State<EmailSplitField> {
  late final TextEditingController _controller;
  bool _focused = false;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  String? get email {
    final value = _controller.text.trim();
    return _emailRegex.hasMatch(value) ? value : null;
  }

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialUsername != null && widget.initialDomain != null)
        ? '${widget.initialUsername}@${widget.initialDomain}'
        : '';
    _controller = TextEditingController(text: initial);
    _controller.addListener(() => widget.onChanged(email));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _focused ? AppColors.brand : Colors.grey.shade200, width: _focused ? 1.4 : 1),
          boxShadow: [
            BoxShadow(
              color: _focused ? AppColors.brand.withOpacity(0.08) : Colors.black.withOpacity(0.03),
              blurRadius: _focused ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(fontSize: 15, color: Colors.black),
          decoration: InputDecoration(
            hintText: 'E-posta adresiniz',
            hintStyle: TextStyle(fontSize: 15, color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.mail_outline, size: 20, color: _focused ? AppColors.brand : Colors.grey.shade400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }
}
