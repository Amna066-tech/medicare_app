import 'package:flutter_test/flutter_test.dart';

import 'package:medicare_app/main.dart';

void main() {
  testWidgets('App loads successfully test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MedicareApp());

    // Verify that our success message is on the screen.
    expect(find.text('Firebase Connected Successfully!'), findsOneWidget);
  });
}