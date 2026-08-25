import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';

/// "Bu Yıl" özet ekranı — kullanıcının yıllık kullanım özetini gösterir.
class YearInReviewScreen extends StatefulWidget {
  const YearInReviewScreen({super.key});

  @override
  State<YearInReviewScreen> createState() => _YearInReviewScreenState();
}

class _YearInReviewScreenState extends State<YearInReviewScreen> {
  final Dio _dio = ApiClient().dio;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _dio.get('/stats/me/year-in-review');
    setState(() => _data = res.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppPageHeader(
        title: '${_data?['year'] ?? ''} Özeti',
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: _data == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_data!['year']} yılında...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _StatLine(value: '${_data!['questionsAsked']}', label: 'soru sordunuz'),
                  _StatLine(value: '${_data!['favoritesAdded']}', label: 'doküman/cevap favoriledi niz'),
                  _StatLine(value: '${_data!['commentsWritten']}', label: 'topluluk yorumu yazdınız'),
                  if (_data!['mostActiveMonth'] != null)
                    _StatLine(value: _data!['mostActiveMonth'], label: 'en aktif ayınızdı', isText: true),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Bu emek, sahadaki işinize değer katıyor. 👏',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String value;
  final String label;
  final bool isText;

  const _StatLine({required this.value, required this.label, this.isText = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.brand, fontSize: isText ? 32 : 44, fontWeight: FontWeight.w800),
          ),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }
}
