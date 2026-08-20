import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/screens/create_protocol_screen.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('protocol title accepts multiple lines', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: CreateProtocolScreen(
          initialProtocol: Protocol(
            id: 'title-test',
            title: 'Line one',
            objective: '',
            description: '',
            steps: const [],
          ),
        ),
      ),
    );
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('protocol-title-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.maxLines, isNull);
    expect(editable.keyboardType, TextInputType.multiline);

    await tester.enterText(
      find.byKey(const Key('protocol-title-field')),
      'Line one\nLine two',
    );
    expect(find.text('Line one\nLine two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
