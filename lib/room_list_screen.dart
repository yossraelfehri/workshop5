import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'queue_provider.dart';
import 'main.dart'; // Pour WaitingRoomScreen

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les rooms au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QueueProvider>().fetchWaitingRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<QueueProvider>().rooms;
    return Scaffold(
      appBar: AppBar(title: const Text('Waiting Rooms')),
      body: rooms.isEmpty
          ? const Center(child: Text('No waiting rooms found.'))
          : ListView.builder(
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                double? toDouble(dynamic v) {
                  if (v == null) return null;
                  if (v is double) return v;
                  if (v is int) return v.toDouble();
                  if (v is String) return double.tryParse(v);
                  return null;
                }
                final lat = toDouble(room['latitude']);
                final lng = toDouble(room['longitude']);
                return Card(
                  child: ListTile(
                    title: Text(room['name'] ?? ''),
                    subtitle: Text(
                      lat != null && lng != null
                          ? 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}'
                          : 'Lat: —, Lng: —',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WaitingRoomScreen(roomId: room['id']?.toString()),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
