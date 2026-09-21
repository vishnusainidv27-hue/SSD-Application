import 'package:flutter_test/flutter_test.dart';

import 'package:admin_mobile_app/main.dart';
import 'package:admin_mobile_app/widgets/credentials_share_dialog.dart';

void main() {
  testWidgets('shows the "not configured" screen when Firebase init fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(SsdApp(firebaseError: Exception('no options')));

    expect(find.text("Firebase isn't configured yet"), findsOneWidget);
  });

  test('credentialsMessage includes the mobile number and password', () {
    final message =
        credentialsMessage(mobile: '9876543210', password: 'milk1234');

    expect(message, contains('Mobile: 9876543210'));
    expect(message, contains('Password: milk1234'));
  });
}
