import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/main.dart';

void main() {
  testWidgets('App starts with Login Screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FitnessApp());

    // Verify that the Login Screen is shown by finding "Sign In" text.
    expect(find.text('Sign In'), findsOneWidget);
  });
}