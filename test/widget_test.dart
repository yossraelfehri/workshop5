import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart'; // ✅ Ajouté pour Provider
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart'; // ✅ Ajouté pour QueueProvider

// Simple fakes to avoid requiring Supabase initialization during widget tests.
class _FakeQuery {
  final List<Map<String, dynamic>> calls = [];

  Future<void> insert(Map<String, dynamic> data) async {
    calls.add(data);
  }

  Future<void> delete() async {}
  Future<void> match(Map<String, dynamic> _) async {}
}

class _FakeClient {
  final _FakeQuery query;
  _FakeClient(this.query);
  dynamic from(String _) => query;
}

void main() {
  testWidgets('App displays initial queue and adds a client', (WidgetTester tester) async {
    // Simple fakes to avoid requiring Supabase initialization during widget tests.
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);

    // ✅ Fournir QueueProvider dans l’arbre de widgets
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => QueueProvider.forTesting(fakeClient),
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );

    // ✅ Vérifie que la file est vide au départ
    expect(find.text('Clients in Queue: 0'), findsOneWidget);

    // ✅ Ajoute un client
    await tester.enterText(find.byType(TextField), 'John Doe');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(); // Rebuild après notifyListeners()

    // ✅ Vérifie que le client est affiché
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
  });
}
