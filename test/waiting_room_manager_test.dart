import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/queue_provider.dart';

// Simple fakes to avoid requiring Supabase initialization during tests.
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
  test('should add a client to the waiting list', () async {
    // ARRANGE
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);
    final manager = QueueProvider.forTesting(fakeClient);

    // ACT
    await manager.addClient('John Doe');

    // ASSERT
    expect(manager.clients.length, equals(1));
    expect(manager.clients.first.name, equals('John Doe'));
  });

  test('should remove the first client when nextClient() is called', () async {
    // ARRANGE
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);
    final manager = QueueProvider.forTesting(fakeClient);
    await manager.addClient('Client A');
    await manager.addClient('Client B');

    // ACT
    await manager.nextClient();

    // ASSERT
    expect(manager.clients.length, 1);
    expect(manager.clients.first.name, 'Client B');
  });
}
