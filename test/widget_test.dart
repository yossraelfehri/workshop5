import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/main.dart';

void main() {
  testWidgets('App displays initial queue and adds a client', (WidgetTester tester) async {
    // ARRANGE
    await tester.pumpWidget(const WaitingRoomApp());

    // ASSERT: Vérifie que la file est vide au départ
    expect(find.text('Clients in Queue: 0'), findsOneWidget);

    // ACT: Ajoute un client
    await tester.enterText(find.byType(TextField), 'John Doe');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(); // Rebuild après setState()

    // ASSERT: Vérifie que le client est affiché
    expect(find.text('John Doe'), findsAtLeastNWidgets(1)); // ← corrigé ici
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
  });
}
