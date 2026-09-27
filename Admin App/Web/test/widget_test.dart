import 'package:admin_web_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the "not configured" screen when Firebase init fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(SsdApp(firebaseError: Exception('no options')));

    expect(find.text("Firebase isn't configured yet"), findsOneWidget);
  });
}
