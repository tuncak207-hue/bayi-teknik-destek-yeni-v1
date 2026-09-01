import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import 'quick_actions_data.dart';

class ReorderQuickActionsScreen extends StatefulWidget {
  const ReorderQuickActionsScreen({super.key});

  @override
  State<ReorderQuickActionsScreen> createState() => _ReorderQuickActionsScreenState();
}

class _ReorderQuickActionsScreenState extends State<ReorderQuickActionsScreen> {
  List<QuickActionDef> _order = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await QuickActionsOrder.getOrdered();
    setState(() {
      _order = order;
      _loading = false;
    });
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    await QuickActionsOrder.save(_order);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: const AppPageHeader(title: AppLocalizations.of(context)!.screenReorderQuickActions),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'En sık kullandığınız işlemi en üste taşımak için sürükleyin — Ana Sayfa\'da bu sırayla görünür.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: _order.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final action = _order[index];
                      return Card(
                        key: ValueKey(action.id),
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: ListTile(
                          leading: Icon(action.icon, color: AppColors.navy),
                          title: Text(action.label),
                          trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
