import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_theme.dart';
import '../ai_assistant/data/ai_repository.dart';

/// Elleri dolu/araç içi kullanım için: tek dokunuşla mikrofona konuşup
/// soruyu doğrudan AI'a gönderen hızlı erişim penceresi. Yazı kutusuna
/// dökülüp elle "gönder" denmesi gerekmez — konuş, bitince otomatik gider.
class VoiceQuickQuestionSheet extends StatefulWidget {
  const VoiceQuickQuestionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceQuickQuestionSheet(),
    );
  }

  @override
  State<VoiceQuickQuestionSheet> createState() => _VoiceQuickQuestionSheetState();
}

enum _SheetState { idle, listening, sending, error }

class _VoiceQuickQuestionSheetState extends State<VoiceQuickQuestionSheet> {
  final _speech = stt.SpeechToText();
  final _repository = AiRepository();
  _SheetState _state = _SheetState.idle;
  String _transcript = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final available = await _speech.initialize(
      onError: (_) => setState(() {
        _state = _SheetState.error;
        _errorText = 'Mikrofon başlatılamadı. Cihaz izinlerini kontrol edin.';
      }),
    );
    if (!available) {
      setState(() {
        _state = _SheetState.error;
        _errorText = 'Ses tanıma bu cihazda kullanılamıyor.';
      });
      return;
    }
    setState(() => _state = _SheetState.listening);
    _speech.listen(
      localeId: 'tr_TR',
      onResult: (result) {
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult) _send();
      },
    );
  }

  Future<void> _send() async {
    await _speech.stop();
    if (_transcript.trim().isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _state = _SheetState.sending);
    try {
      final result = await _repository.ask(question: _transcript.trim());
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/ai/conversation/${result.conversationId}');
    } catch (e) {
      setState(() {
        _state = _SheetState.error;
        _errorText = 'Soru gönderilemedi, internet bağlantınızı kontrol edin.';
      });
    }
  }

  Future<void> _cancel() async {
    await _speech.stop();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_state == _SheetState.error) ...[
            const Icon(Icons.error_outline, color: AppColors.brand, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(_errorText ?? 'Bir hata oluştu.', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          ] else ...[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _state == _SheetState.listening
                    ? AppColors.brand.withOpacity(0.12)
                    : AppColors.navy.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _state == _SheetState.sending ? Icons.send_outlined : Icons.mic,
                size: 38,
                color: _state == _SheetState.listening ? AppColors.brand : AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _state == _SheetState.listening
                  ? 'Dinliyorum... sorunuzu söyleyin'
                  : _state == _SheetState.sending
                      ? 'Gönderiliyor...'
                      : 'Hazırlanıyor...',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_transcript.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(AppSpacing.radius)),
                child: Text(_transcript, textAlign: TextAlign.center),
              ),
            const SizedBox(height: AppSpacing.md),
            if (_state == _SheetState.listening)
              TextButton(onPressed: _send, child: const Text('Bitirdim, Gönder'))
            else if (_state != _SheetState.sending)
              TextButton(onPressed: _cancel, child: const Text('Vazgeç')),
          ],
        ],
      ),
    );
  }
}
