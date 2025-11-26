import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart';
import 'package:waiting_room_app/connectivity_service.dart';

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

// Utilise un vrai ConnectivityService pour les tests
// Il va essayer de se connecter mais en test ça devrait fonctionner

void main() {
  testWidgets('should add a new client to the list on button tap', (WidgetTester tester) async {
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivityService),
          ChangeNotifierProvider(
            create: (_) => QueueProvider.forTesting(fakeClient, connectivity: connectivityService),
          ),
        ],
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );
    await tester.pumpAndSettle(); // Attendre l'initialisation

    // Ajoute un client
    await tester.enterText(find.byType(TextField), 'Client A');
    final addButton = find.byType(ElevatedButton);
    await tester.ensureVisible(addButton);
    await tester.tap(addButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Vérifie que le client est affiché
    expect(find.text('Client A'), findsOneWidget);
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
  });

  testWidgets('should remove a client from the list when the delete button is tapped', (WidgetTester tester) async {
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivityService),
          ChangeNotifierProvider(
            create: (_) => QueueProvider.forTesting(fakeClient, connectivity: connectivityService),
          ),
        ],
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );
    await tester.pumpAndSettle(); // Attendre l'initialisation

    // Ajoute un client
    await tester.enterText(find.byType(TextField), 'Bob');
    final addButton = find.byType(ElevatedButton);
    await tester.ensureVisible(addButton);
    await tester.tap(addButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Vérifie que le client est présent
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Clients in Queue: 1'), findsOneWidget);

    // Trouve et appuie sur le bouton de suppression
    final deleteButton = find.descendant(
      of: find.byType(ListTile).first,
      matching: find.byIcon(Icons.delete),
    );
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Vérifie que le client a été supprimé
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Clients in Queue: 0'), findsOneWidget);
  });

  testWidgets('should remove the first client from the list when "Next Client" is tapped', (WidgetTester tester) async {
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: connectivityService),
          ChangeNotifierProvider(
            create: (context) => QueueProvider.forTesting(fakeClient, connectivity: connectivityService),
          ),
        ],
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );
    await tester.pumpAndSettle(); // Attendre l'initialisation complète

    // Ajoute deux clients
    await tester.enterText(find.byType(TextField), 'Client A');
    final addButton1 = find.byType(ElevatedButton);
    await tester.ensureVisible(addButton1);
    await tester.tap(addButton1, warnIfMissed: false);
    await tester.pumpAndSettle();
    
    // Vérifier que le premier client est bien ajouté
    expect(find.text('Client A'), findsOneWidget);
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
    
    await tester.enterText(find.byType(TextField), 'Client B');
    final addButton2 = find.byType(ElevatedButton);
    await tester.ensureVisible(addButton2);
    await tester.tap(addButton2, warnIfMissed: false);
    await tester.pumpAndSettle();
    
    // Vérifier que les deux clients sont présents
    expect(find.text('Client A'), findsOneWidget);
    expect(find.text('Client B'), findsOneWidget);
    expect(find.text('Clients in Queue: 2'), findsOneWidget);

    // S'assurer que le bouton est visible avant de cliquer
    final nextButton = find.byKey(const Key('nextClientButton'));
    await tester.ensureVisible(nextButton);
    await tester.pumpAndSettle();
    
    // Appuie sur le bouton "Next Client"
    await tester.tap(nextButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Vérifie que seul Client B reste
    expect(find.text('Client A'), findsNothing);
    expect(find.text('Client B'), findsOneWidget);
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
  });
}
