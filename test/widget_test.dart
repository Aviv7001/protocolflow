import 'package:flutter_test/flutter_test.dart';

import 'package:protocolflow/main.dart';

void main() {
  testWidgets('ProtocolFlow home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProtocolFlowApp());
    await tester.pump();

    expect(find.text('Today\'s Tasks'), findsOneWidget);
    expect(find.text('Running Protocols'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
  });
}
