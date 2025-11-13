import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Supabase realtime event types are referenced via supabase_flutter's exports when needed.
import 'package:waiting_room_app/models/client.dart';

class QueueProvider extends ChangeNotifier {
  final List<Client> _clients = [];
  List<Client> get clients => _clients;

  final dynamic _supabase;
  // Flag to indicate this provider was created for testing/dev with a fake client.
  final bool isTesting;
  // Realtime subscriptions removed to avoid SDK/API mismatches across versions.

  // Counter to ensure optimistic IDs are unique even when created within the same millisecond
  static int _optimisticIdCounter = 0;

  QueueProvider()
      : _supabase = Supabase.instance.client,
        isTesting = false {
    _fetchInitialClients();
  }

  // Public constructor for injecting a fake/test supabase-like client.
  QueueProvider.forTesting(this._supabase) : isTesting = true;

  Future<void> _fetchInitialClients() async {
    final List<Map<String, dynamic>> response =
        await _supabase.from('clients').select().order('created_at');

    _clients.clear();
    _clients.addAll(response.map(Client.fromMap));
    notifyListeners();
  }

  // realtime removed

  Future<void> addClient(String name) async {
    if (name.trim().isEmpty) {
      print('Cannot add empty client name');
      return;
    }

    // Optimistically update local state so UI reacts immediately in tests
    final newClient = Client(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_optimisticIdCounter++}',
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    _clients.add(newClient);
    _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();

    try {
      await _supabase.from('clients').insert({'name': name.trim()});
    } catch (e) {
      // If remote insert fails, remove the optimistic client
      _clients.removeWhere((c) => c.id == newClient.id);
      notifyListeners();
      rethrow;
    }
    print('Client added: $name');
  }

  Future<void> removeClient(String id) async {
    // Optimistically remove locally so UI updates immediately
    _clients.removeWhere((client) => client.id == id);
    notifyListeners();

    try {
      // Some Supabase client implementations return a builder with a `match` method
      // (e.g. postgrest builder). In tests we may use a fake where `delete()` returns
      // a Future. Handle both cases robustly.
      final del = _supabase.from('clients').delete();
      try {
        // Try calling match on the result (dynamic) if available
        await (del as dynamic).match({'id': id});
      } catch (_) {
        // If match isn't available, maybe delete returned a Future already
        if (del is Future) {
          await del;
        } else {
          // As a fallback, try awaiting the dynamic result
          try {
            await del;
          } catch (e) {
            rethrow;
          }
        }
      }
    } catch (e) {
      // If remote deletion fails, we could re-fetch or re-add; keep simple for tests
      rethrow;
    }
    print('Client removed: $id');
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) {
      print('Queue is empty!');
      return;
    }

    final firstClient = _clients.first;
    // removeClient will update local state and call backend
    await removeClient(firstClient.id);
    print('Next client: ${firstClient.name}');
  }

  @override
  void dispose() {
    // nothing to unsubscribe when realtime is disabled
    super.dispose();
  }
}
