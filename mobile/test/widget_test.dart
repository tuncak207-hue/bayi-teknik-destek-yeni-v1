import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayi_teknik_destek/core/widgets/app_components.dart';
import 'package:bayi_teknik_destek/core/widgets/design_system.dart';

void main() {
  testWidgets('Ortak mobil sayfa başlığı oluşturuluyor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: AppPageHeader(title: 'Test ekranı'),
        ),
      ),
    );

    expect(find.text('Test ekranı'), findsOneWidget);
    expect(find.byTooltip('Geri'), findsOneWidget);
  });

  testWidgets('Ortak durum bileşenleri erişilebilir etiketler sunuyor', (WidgetTester tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: const Scaffold(
          body: Column(
            children: [
              AppButton(label: 'Gönder', onPressed: null),
              AppLoadingState(lines: 1),
              AppEmptyState(
                icon: Icons.inbox_outlined,
                title: 'Kayıt yok',
                description: 'Henüz veri bulunmuyor.',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Gönder'), findsOneWidget);
    final loadingSemantics = tester.getSemantics(find.byType(AppLoadingState));
    expect(loadingSemantics.label, 'Yükleniyor');
    final emptySemantics = tester.getSemantics(find.byType(AppEmptyState));
    expect(emptySemantics.label, contains('Kayıt yok'));
    expect(emptySemantics.label, contains('Henüz veri bulunmuyor'));
    semanticsHandle.dispose();
  });

  testWidgets('Başlık rozeti başlığın yanında render ediliyor', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppPageHeader(
            title: 'Favorilerim',
            titleBadge: const Semantics(
              label: '3 favori',
              child: Chip(label: Text('3')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Favorilerim'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('3 favori'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ortak input dark temada render ediliyor', (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            label: 'Arama',
            icon: Icons.search,
          ),
        ),
      ),
    );

    expect(find.text('Arama'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
