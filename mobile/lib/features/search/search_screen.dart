import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';

enum _SearchScope { all, documents, dealers, posts }

class SearchScreen extends StatefulWidget {
  final bool documentsOnly;

  const SearchScreen({super.key, this.documentsOnly = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final Dio _dio = ApiClient().dio;
  final _controller = TextEditingController();
  Map<String, dynamic>? _results;
  bool _loading = false;
  late _SearchScope _scope;
  List<String> _recentSearches = [];
  static const _kRecentSearchesKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    _scope = widget.documentsOnly ? _SearchScope.documents : _SearchScope.all;
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _recentSearches = prefs.getStringList(_kRecentSearchesKey) ?? []);
  }

  Future<void> _saveRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [query, ..._recentSearches.where((q) => q != query)].take(8).toList();
    setState(() => _recentSearches = updated);
    await prefs.setStringList(_kRecentSearchesKey, updated);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
    setState(() => _recentSearches = []);
  }

  Future<void> _startChat(String dealerId) async {
    final res = await _dio.post('/chat/conversations/direct', data: {'otherUserId': dealerId});
    if (!mounted) return;
    context.push('/chat/${res.data['id']}');
  }

  Future<void> _search([String? overrideQuery]) async {
    final q = (overrideQuery ?? _controller.text).trim();
    if (q.isEmpty) return;
    _controller.text = q;
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/search', queryParameters: {'q': q});
      setState(() => _results = res.data);
      _saveRecentSearch(q);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = _scope == _SearchScope.all || _scope == _SearchScope.documents
        ? (_results?['documents'] as List?) ?? []
        : [];
    final dealers = _scope == _SearchScope.all || _scope == _SearchScope.dealers ? (_results?['dealers'] as List?) ?? [] : [];
    final posts = _scope == _SearchScope.all || _scope == _SearchScope.posts ? (_results?['posts'] as List?) ?? [] : [];
    final hasSearched = _results != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
        children: [
          AppPageHeader(title: widget.documentsOnly ? 'Doküman Ara' : 'Arama'),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Doküman, model, marka veya bayi ara...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            _controller.clear();
                            _results = null;
                          }),
                        ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ScopeChip(label: 'Tümü', selected: _scope == _SearchScope.all, onTap: () => setState(() => _scope = _SearchScope.all)),
                  const SizedBox(width: 6),
                  _ScopeChip(
                    label: 'Dokümanlar',
                    selected: _scope == _SearchScope.documents,
                    onTap: () => setState(() => _scope = _SearchScope.documents),
                  ),
                  const SizedBox(width: 6),
                  _ScopeChip(
                    label: 'Bayiler',
                    selected: _scope == _SearchScope.dealers,
                    onTap: () => setState(() => _scope = _SearchScope.dealers),
                  ),
                  const SizedBox(width: 6),
                  _ScopeChip(
                    label: 'Gönderiler',
                    selected: _scope == _SearchScope.posts,
                    onTap: () => setState(() => _scope = _SearchScope.posts),
                  ),
                ],
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: !hasSearched
                ? (_recentSearches.isEmpty
                    ? const _EmptyHint()
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text('SON ARAMALAR', style: AppText.eyebrow),
                                  const SizedBox(width: AppSpacing.xs),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                    ),
                                    child: Text(
                                      '${_recentSearches.length}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(onPressed: _clearRecentSearches, child: const Text('Temizle', style: TextStyle(fontSize: 12.5))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _recentSearches
                                .map((q) => ActionChip(
                                      label: Text(q, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      avatar: Icon(Icons.history, size: 15, color: AppColors.textMuted),
                                      backgroundColor: Colors.white,
                                      elevation: 1,
                                      side: BorderSide.none,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      onPressed: () => _search(q),
                                    ))
                                .toList(),
                          ),
                        ],
                      ))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    children: [
                      if (documents.isNotEmpty) ...[
                        const _SectionHeader(title: 'Dokümanlar', icon: Icons.description_outlined),
                        ...documents.map((d) => _ResultCard(
                              icon: Icons.picture_as_pdf_outlined,
                              iconColor: AppColors.navy,
                              title: d['title'] ?? '',
                              subtitle: '${d['brand']} / ${d['model']}',
                              onTap: () => context.push('/documents/${d['id']}'),
                            )),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (dealers.isNotEmpty) ...[
                        const _SectionHeader(title: 'Bayiler', icon: Icons.groups_outlined),
                        ...dealers.map((u) => _ResultCard(
                              avatarLetter: (u['company'] as String? ?? '?').characters.first.toUpperCase(),
                              title: u['company'] ?? '',
                              subtitle: '${u['firstName']} ${u['lastName']}',
                              trailingIcon: Icons.chat_bubble_outline,
                              onTap: () => _startChat(u['id']),
                            )),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (posts.isNotEmpty) ...[
                        const _SectionHeader(title: 'Bayilere Sor Gönderileri', icon: Icons.forum_outlined),
                        ...posts.map((p) => _ResultCard(
                              icon: Icons.forum_outlined,
                              iconColor: AppColors.brand,
                              title: p['title'] ?? '',
                              subtitle: p['body'] ?? '',
                              onTap: () => context.push('/community/${p['id']}'),
                            )),
                      ],
                      if (documents.isEmpty && dealers.isEmpty && posts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xl),
                          child: StandardCard(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off, size: 44, color: Colors.grey.shade300),
                                  const SizedBox(height: 10),
                                  Text('Sonuç bulunamadı.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.brand,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.navy, fontWeight: FontWeight.w700, fontSize: 12),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? Colors.transparent : Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}

/// Arama sonuçlarındaki tek bir satır — Design System'deki StandardCard'a
/// dayanır, tutarlı ikon/renk dili kullanır.
class _ResultCard extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String? avatarLetter;
  final String title;
  final String subtitle;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const _ResultCard({
    this.icon,
    this.iconColor,
    this.avatarLetter,
    required this.title,
    required this.subtitle,
    this.trailingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: StandardCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        onTap: onTap,
        child: Row(
          children: [
            if (avatarLetter != null)
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.navy,
                child: Text(avatarLetter!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: (iconColor ?? AppColors.navy).withOpacity(0.08), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: iconColor ?? AppColors.navy, size: 18),
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(trailingIcon ?? Icons.chevron_right, size: 18, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 72),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: StandardCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.05), shape: BoxShape.circle),
                    child: Icon(Icons.search, size: 32, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Doküman, marka/model veya bayi adı yazarak arama yapın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
