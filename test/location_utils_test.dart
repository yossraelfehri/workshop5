import 'package:test/test.dart';
import 'package:waiting_room_app/location_utils.dart';

void main() {
  test('calculateDistance returns non-zero for close coordinates', () {
    final distance = calculateDistance(0, 0, 0.001, 0.001);
    expect(distance, greaterThan(0));
  });
}
