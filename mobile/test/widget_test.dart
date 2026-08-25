import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
