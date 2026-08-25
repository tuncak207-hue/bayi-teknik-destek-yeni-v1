import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayi_teknik_destek/app/app.dart';

void main() {
  testWidgets('Bayi Teknik Destek uygulama kabuğu oluşturuluyor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BayiTeknikDestekApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
