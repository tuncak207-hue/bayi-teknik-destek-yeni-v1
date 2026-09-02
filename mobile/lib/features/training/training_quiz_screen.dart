import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';

/// Kullanıcı isteği: "AI Sınav/Sertifikasyon Motoru" — eğitim içeriğini
/// "izledi/izlemedi" yerine, AI'nin ürettiği kısa bir sınavla gerçekten
/// öğrenip öğrenmediğini ölçer. %70 ve üzeri "Sertifikalı" sayılır.
class TrainingQuizScreen extends StatefulWidget {
  final String trainingId;
  final String trainingTitle;

  const TrainingQuizScreen({super.key, required this.trainingId, required this.trainingTitle});

  @override
  State<TrainingQuizScreen> createState() => _TrainingQuizScreenState();
}

class _TrainingQuizScreenState extends State<TrainingQuizScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic>? _questions;
  final List<int?> _answers = [];
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get('/training/${widget.trainingId}/quiz');
      final questions = res.data as List;
      setState(() {
        _questions = questions;
        _answers.addAll(List<int?>.filled(questions.length, null));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Sınav yüklenemedi, lütfen tekrar deneyin.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_answers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm soruları cevaplayın.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _dio.post('/training/${widget.trainingId}/quiz/submit', data: {'answers': _answers});
      setState(() {
        _result = res.data;
        _submitting = false;
      });
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sınav gönderilemedi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: Text(widget.trainingTitle, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.navy)))
              : _result != null
                  ? _buildResult()
                  : _buildQuiz(),
    );
  }

  Widget _buildResult() {
    final passed = _result!['passed'] == true;
    final score = _result!['score'];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed ? Icons.verified_outlined : Icons.replay_outlined,
              size: 72,
              color: passed ? AppColors.success : Colors.orange.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? 'Tebrikler, Sertifikalısınız!' : 'Bu sefer olmadı',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Puanınız: %$score  (${_result!['correctCount']}/${_result!['totalQuestions']} doğru)',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              passed ? 'Bu eğitim otomatik olarak tamamlandı sayıldı.' : 'Geçmek için en az %70 puan almanız gerekiyor. Tekrar deneyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(passed),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: const Text('Kapat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (var i = 0; i < _questions!.length; i++) _buildQuestionCard(i),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Sınavı Bitir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions![index];
    final options = (q['options'] as List).cast<String>();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}. ${q['question']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 8),
          ...List.generate(options.length, (optIndex) {
            final selected = _answers[index] == optIndex;
            return InkWell(
              onTap: () => setState(() => _answers[index] = optIndex),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand.withValues(alpha: 0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? AppColors.brand : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: selected ? AppColors.brand : Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Expanded(child: Text(options[optIndex], style: const TextStyle(fontSize: 13, color: AppColors.navy))),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
