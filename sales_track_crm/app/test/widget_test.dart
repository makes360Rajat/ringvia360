import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sales_track_crm/main.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SalesTrackApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SalesTrackApp());
    expect(find.byType(SalesTrackApp), findsOneWidget);
  });
}
