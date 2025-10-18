// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/main.dart';

void main() {
  testWidgets('App displays WaitingRoomCard with correct name', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Vérifie que le texte "Hello," est affiché
    expect(find.text('Hello,'), findsOneWidget);

    // Vérifie que le nom "John Doe" est affiché
    expect(find.text('John Doe'), findsOneWidget);
  });
}
