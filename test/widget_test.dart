import 'package:etisalaty/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows login screen when no user is stored', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.contacts), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
