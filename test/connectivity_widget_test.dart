import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart';
import 'package:waiting_room_app/connectivity_service.dart';

class FakeConnectivityService extends ChangeNotifier implements ConnectivityService {
  @override
  bool get isOnline => false;
}

void main() {
  testWidgets('Offline Banner visible when offline', (WidgetTester tester) async {
    final fakeConnectivity = FakeConnectivityService();
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityService>.value(value: fakeConnectivity),
          ChangeNotifierProvider(
            create: (_) => QueueProvider.forTesting(fakeClient, connectivity: fakeConnectivity),
          ),
        ],
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vous êtes hors ligne'), findsOneWidget);
  });
}

// Simple fakes pour éviter l'initialisation Supabase
class _FakeQuery {
  final List<Map<String, dynamic>> calls = [];
  Future<void> insert(Map<String, dynamic> data) async => calls.add(data);
  Future<void> delete() async {}
  Future<void> match(Map<String, dynamic> _) async {}
}

class _FakeClient {
  final _FakeQuery query;
  _FakeClient(this.query);
  dynamic from(String _) => query;
}
