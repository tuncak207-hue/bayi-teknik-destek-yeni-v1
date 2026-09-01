import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/design_system.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/app_theme.dart';

class CommunityPostScreen extends StatefulWidget {
  final String postId;
  const CommunityPostScreen({super.key, required this.postId});

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  final Dio _dio = ApiClient().dio;
  final _commentController = TextEditingController();
  Map<String, dynamic>? _post;
  bool _loading = true;
  bool _sendingComment = false;
  bool _askingAi = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _dio.get('/community/posts/${widget.postId}');
    setState(() {
      _post = res.data;
      _loading = false;
    });
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await _dio.post('/community/posts/${widget.postId}/comments', data: {'body': text});
      _commentController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _askAi() async {
    setState(() => _askingAi = true);
    try {
      await _dio.post('/community/posts/${widget.postId}/ask-ai');
      await _load();
    } finally {
      if (mounted) setState(() => _askingAi = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteComment),
        content: Text(AppLocalizations.of(context)!.deleteCommentConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: AppColors.navy)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/community/comments/$commentId');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _post == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final comments = (_post!['comments'] as List?) ?? [];
    final author = _post!['author'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(title: AppLocalizations.of(context)!.qaCommunity),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_post!['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
                        const SizedBox(height: 6),
                        Text(
                          author != null ? '${author['company']} — ${author['firstName']} ${author['lastName']}' : '',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(_post!['body'] ?? ''),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(AppLocalizations.of(context)!.commentsCountLabel(comments.length), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _askingAi ? null : _askAi,
                      icon: _askingAi
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.smart_toy_outlined, size: 16),
                      label: Text(AppLocalizations.of(context)!.askAiForHelp),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ...comments.map((c) {
                  final isAi = c['isAI'] == true;
                  final commentAuthor = c['author'];
                  final isMyComment = commentAuthor != null && commentAuthor['id'] == CurrentUser().id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isAi ? Icons.smart_toy_outlined : Icons.person_outline,
                                size: 15,
                                color: isAi ? AppColors.brand : AppColors.navy,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isAi ? 'AI destekli topluluk cevabı' : '${commentAuthor?['firstName'] ?? ''} ${commentAuthor?['lastName'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isAi ? AppColors.brand : AppColors.navy,
                                  ),
                                ),
                              ),
                              if (isMyComment)
                                InkWell(
                                  onTap: () => _deleteComment(c['id']),
                                  child: Icon(Icons.delete_outline, size: 16, color: Colors.grey.shade500),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          isAi
                              ? MarkdownBody(data: c['body'] ?? '', selectable: true)
                              : Text(c['body'] ?? ''),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(hintText: 'Yorum yazın...'),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(
                    onPressed: _sendingComment ? null : _addComment,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
