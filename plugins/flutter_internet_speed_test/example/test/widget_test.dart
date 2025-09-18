import 'package:flutter/material.dart';
import 'package:network_predicter/main.dart'; // 👈 import your own app’s main.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads MyApp widget', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp()); // 👈 This must match your app’s root widget

    // Example: Check that a Text widget exists somewhere
    expect(find.byType(Text), findsWidgets);
  });
}

