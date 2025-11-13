import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/queue_provider.dart';

class _FakeQuery {
  final List<Map<String, dynamic>> calls = [];

  Future<void> insert(Map<String, dynamic> data) async {
    calls.add(data);
  }
}

class _FakeClient {
  final _FakeQuery query;
  _FakeClient(this.query);
  dynamic from(String _) => query;
}

void main() {
  test('addClient calls insert', () async {
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);

    final provider = QueueProvider.forTesting(fakeClient);
    await provider.addClient("Alice");

    expect(fakeQuery.calls, isNotEmpty);
    expect(fakeQuery.calls.first, containsPair('name', 'Alice'));
  });
}
