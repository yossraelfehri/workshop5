import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/waiting_room_manager.dart';

void main() {
  test('should add a client to the waiting list', () {
    // ARRANGE
    final manager = WaitingRoomManager();

    // ACT
    manager.addClient('John Doe');

    // ASSERT
    expect(manager.clients.length, equals(1));
    expect(manager.clients.first, equals('John Doe'));
  });
}
