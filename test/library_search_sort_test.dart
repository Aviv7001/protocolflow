import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/screens/library_screen.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('library searches and sorts templates by date', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final alpha = Protocol(
      id: 'alpha',
      title: 'Alpha protocol',
      objective: '',
      description: '',
      steps: const [],
      isTemplate: true,
      createdAt: DateTime.utc(2026, 8, 12),
    );
    final beta = Protocol(
      id: 'beta',
      title: 'Beta protocol',
      objective: '',
      description: '',
      steps: const [],
      isTemplate: true,
      createdAt: DateTime.utc(2025, 8, 12),
    );
    SharedPreferences.setMockInitialValues({
      'protocols_library_json': jsonEncode([alpha.toJson(), beta.toJson()]),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: const LibraryScreen(embedded: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alpha protocol')).dy,
      lessThan(tester.getTopLeft(find.text('Beta protocol')).dy),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search protocols...'),
      'beta',
    );
    await tester.pump();
    expect(find.text('Alpha protocol'), findsNothing);
    expect(find.text('Beta protocol'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.tap(find.byTooltip('Sort by date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date (ascending)'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Beta protocol')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha protocol')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
