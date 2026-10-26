import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('RingVia360App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RingVia360App());
    await tester.pumpAndSettle();

    // Verify the dialer header loads
    expect(find.text('RingVia360 Mobile'), findsOneWidget);
    expect(find.text('Enter Phone Number'), findsOneWidget);
  });
}
