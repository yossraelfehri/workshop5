import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:waiting_room_app/location_utils.dart';

import 'local_queue_service.dart';
import 'package:waiting_room_app/models/client.dart';
import 'geolocation_service.dart';
import 'package:waiting_room_app/connectivity_service.dart';

/// QueueProvider manages the waiting queue, local persistence and best-effort
/// sync to Supabase. It exposes a `forTesting` constructor so tests can inject
/// a fake Supabase-like client and use an in-memory local DB.
class QueueProvider extends ChangeNotifier {
  final dynamic _supabase; // SupabaseClient at runtime, or a test/fake client
  final LocalQueueService _localDb;
  final GeolocationService _geoService;
  final ConnectivityService? _connectivity;

  /// When true, the provider will avoid realtime subscriptions and use an
  /// in-memory DB for tests.
  final bool isTesting;

  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> get rooms => _rooms;

  List<Client> _clients = [];
  String? _currentRoomId;
  List<Client> get clients {
    if (_currentRoomId == null) return _clients;
    return _clients.where((c) => c.waitingRoomId == _currentRoomId).toList();
  }

  dynamic _subscription;

  static const int _pageSize = 20;
  int _offset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  QueueProvider({ConnectivityService? connectivity})
    : _supabase = Supabase.instance.client,
      _localDb = LocalQueueService(),
      _geoService = GeolocationService(),
      isTesting = false,
      _connectivity = connectivity {
    _init();
  }

  QueueProvider.forTesting(dynamic client, {ConnectivityService? connectivity})
    : _supabase = client,
      _localDb = LocalQueueService(inMemory: true),
      _geoService = GeolocationService(),
      isTesting = true,
      _connectivity = connectivity {
    _init();
  }

  Future<void> fetchWaitingRooms() async {
    try {
      // Essayer de récupérer depuis Supabase
      final response = await _supabase.from('waiting_rooms').select();
      List<dynamic>? rows;
      try {
        final err = response.error;
        if (err != null) {
          throw Exception('Supabase error: $err');
        } else {
          rows = response.data as List<dynamic>?;
        }
      } catch (_) {
        if (response is List) rows = response;
      }
      
      if (rows != null && rows.isNotEmpty) {
        _rooms = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
        // Sauvegarder localement pour usage hors ligne
        for (var room in _rooms) {
          await _localDb.insertRoomLocally(room);
        }
        notifyListeners();
      } else {
        if (!isTesting) {
          await _seedRemoteRoomsAndClients();
          try {
            final reResp = await _supabase.from('waiting_rooms').select();
            List<dynamic>? reRows;
            try {
              final err = reResp.error;
              if (err == null) reRows = reResp.data as List<dynamic>?;
            } catch (_) {
              if (reResp is List) reRows = reResp;
            }
            if (reRows != null && reRows.isNotEmpty) {
              _rooms = reRows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
              for (var room in _rooms) {
                await _localDb.insertRoomLocally(room);
              }
              notifyListeners();
              return;
            }
          } catch (_) {}
        }
        // Si pas de données, charger depuis le local
        await _loadRoomsFromLocal();
        if (_rooms.isEmpty && !isTesting) {
          await _seedLocalRoomsAndClients();
        }
      }
    } catch (e) {
      // En cas d'erreur (hors ligne), charger depuis le local
      // ignore: avoid_print
      print('Failed to fetch rooms from Supabase: $e');
      await _loadRoomsFromLocal();
      if (_rooms.isEmpty && !isTesting) {
        await _seedLocalRoomsAndClients();
      }
    }
  }

  Future<void> _loadRoomsFromLocal() async {
    try {
      final localRooms = await _localDb.getRooms();
      if (localRooms.isNotEmpty) {
        _rooms = localRooms;
        notifyListeners();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load rooms from local: $e');
    }
  }

  Future<void> _init() async {
    try {
      await _loadQueue();
      if (_connectivity != null) {
        bool lastStatus = _connectivity!.isOnline;
        _connectivity!.addListener(() {
          final isNowOnline = _connectivity!.isOnline;
          if (!lastStatus && isNowOnline) {
            _syncLocalToRemote();
          }
          lastStatus = isNowOnline;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('QueueProvider initialization failed: $e');
    }
  }

  Future<void> _loadQueue({String? roomId}) async {
    // Load local immediately
    final rows = await _localDb.getClients();
    _clients = rows.map((m) => Client.fromMap(m)).toList();
    if (roomId != null) {
      _currentRoomId = roomId;
    }
    notifyListeners();

    // Try to sync unsynced rows
    await _syncLocalToRemote();

    // Fetch remote records to merge (skip in testing to avoid network)
    if (!isTesting) {
      await _fetchRemoteClients();
      _setupRealtimeSubscription();
    }
  }

  Future<void> _fetchRemoteClients({bool reset = false, String? roomId}) async {
    if (reset) {
      _offset = 0;
      _clients.clear();
      _hasMore = true;
      _currentRoomId = roomId;
    }
    try {
      var query = _supabase.from('clients').select();
      if (roomId != null) {
        query = query.eq('waiting_room_id', roomId);
      }
      query = query.limit(_pageSize).offset(_offset);
      final resp = await query;
      List<dynamic>? rows;
      try {
        final err = resp.error;
        if (err != null) {
          print('Supabase select error: $err');
        } else {
          rows = resp.data as List<dynamic>?;
        }
      } catch (_) {
        if (resp is List) rows = resp;
      }
      if (rows != null && rows.isNotEmpty) {
        for (var r in rows) {
          try {
            final map = Map<String, dynamic>.from(r as Map);
            map['is_synced'] = 1;
            await _localDb.insertClientLocally(map);
          } catch (e) {
            print('Failed to persist remote row: $e');
          }
        }
        final refreshed = await _localDb.getClients();
        _clients = refreshed.map((m) => Client.fromMap(m)).toList();
        _hasMore = rows.length >= _pageSize;
        _offset += rows.length;
        notifyListeners();
      } else {
        _hasMore = false;
        final refreshed = await _localDb.getClients();
        _clients = refreshed.map((m) => Client.fromMap(m)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Failed to fetch remote clients: $e');
      final refreshed = await _localDb.getClients();
      _clients = refreshed.map((m) => Client.fromMap(m)).toList();
      notifyListeners();
    }
  }

  /// Charge les clients d'une salle spécifique (publique pour être appelée depuis l'UI)
  Future<void> loadClientsForRoom(String roomId) async {
    _currentRoomId = roomId;
    await _fetchRemoteClients(reset: true, roomId: roomId);
    if (!isTesting) {
      subscribeToRoom(roomId);
    }
  }

  /// Appelle cette méthode quand l'utilisateur approche la fin de la liste.
  Future<void> fetchMoreClients({String? roomId}) async {
    if (_hasMore) {
      await _fetchRemoteClients(roomId: roomId ?? _currentRoomId);
    }
  }

  /// Best-effort sync of local unsynced rows to Supabase.
  /// Tries upsert/insert using list payloads (real client) then falls back to
  /// map payloads (test fakes). Marks rows as synced locally on success.
  Future<void> _syncLocalToRemote() async {
    final unsynced = await _localDb.getUnsyncedClients();

    for (var clientRow in unsynced) {
      final remoteClient = Map<String, dynamic>.from(clientRow)
        ..remove('is_synced');
      final id = remoteClient['id']?.toString() ?? '';
      bool synced = false;

      // Helper to inspect a response-like object for `.error`.
      bool responseHasError(dynamic resp) {
        try {
          return resp.error != null;
        } catch (_) {
          return false;
        }
      }

      // Try upsert(list)
      try {
        final upsertResp = await _supabase.from('clients').upsert([
          remoteClient,
        ]);
        // Debug: log response/error when available
        try {
          // ignore: avoid_print
          print('upsert(list) response for $id: ${upsertResp}');
        } catch (_) {}
        if (!responseHasError(upsertResp)) synced = true;
      } catch (_) {
        // ignore and try other shapes
      }

      // Try insert(list)
      if (!synced) {
        try {
          final insertResp = await _supabase.from('clients').insert([
            remoteClient,
          ]);
          try {
            // ignore: avoid_print
            print('insert(list) response for $id: ${insertResp}');
          } catch (_) {}
          if (!responseHasError(insertResp)) synced = true;
        } catch (_) {}
      }

      // Try upsert(map)
      if (!synced) {
        try {
          final upsertResp2 = await _supabase
              .from('clients')
              .upsert(remoteClient);
          try {
            // ignore: avoid_print
            print('upsert(map) response for $id: ${upsertResp2}');
          } catch (_) {}
          if (!responseHasError(upsertResp2)) synced = true;
        } catch (_) {}
      }

      // Try insert(map)
      if (!synced) {
        try {
          final insertResp2 = await _supabase
              .from('clients')
              .insert(remoteClient);
          try {
            // ignore: avoid_print
            print('insert(map) response for $id: ${insertResp2}');
          } catch (_) {}
          if (!responseHasError(insertResp2)) synced = true;
        } catch (e) {
          // ignore
          // ignore: avoid_print
          print('Remote insert failed for $id: $e');
        }
      }

      if (synced) {
        try {
          await _localDb.markClientAsSynced(id);
        } catch (e) {
          // ignore: avoid_print
          print('Marking local client as synced failed for $id: $e');
        }
      }
    }
  }

  Future<String?> _findNearestRoom(double clientLat, double clientLng) async{
    if (_rooms.isEmpty) await fetchWaitingRooms();
    double minDistance = double.infinity;
    String? nearestRoomId;
    for (var room in _rooms) {
      double? toDouble(dynamic v) {
        if (v == null) return null;
        if (v is double) return v;
        if (v is int) return v.toDouble();
        if (v is String) return double.tryParse(v);
        return null;
      }
      final roomLat = toDouble(room['latitude']);
      final roomLng = toDouble(room['longitude']);
      if (roomLat == null || roomLng == null) {
        continue;
      }
      final distance = calculateDistance(clientLat, clientLng, roomLat, roomLng);
      if (distance < minDistance) {
        minDistance = distance;
        nearestRoomId = room['id']?.toString();
      }
    }
    return nearestRoomId;
  }
  
  Future<void> addClient(String name, {String? forcedRoomId}) async {
    if (isTesting) {
      // En mode test, skip géolocalisation et création directe en local
      final id = const Uuid().v4();
      final clientMap = {
        'id': id,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'lat': null,
        'lng': null,
        'waiting_room_id': forcedRoomId,
        'is_synced': 0,
      };
      await _localDb.insertClientLocally(clientMap);
      // Recharger depuis la base pour être cohérent
      final rows = await _localDb.getClients();
      _clients = rows.map((m) => Client.fromMap(m)).toList();
      _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
      return;
    }

    // Mode normal : géolocalisation et recherche de salle
    double? clientLat;
    double? clientLng;
    String? roomId;
    
    try {
      final position = await _geoService.getCurrentPosition();
      clientLat = position?.latitude;
      clientLng = position?.longitude;
      
      if (clientLat != null && clientLng != null) {
        roomId = await _findNearestRoom(clientLat, clientLng);
      }
    } catch (e) {
      // Géolocalisation échouée - on continue sans position
      // ignore: avoid_print
      print('Geolocation failed: $e');
    }

    roomId = roomId ?? forcedRoomId;

    // Insert dans Supabase (avec ou sans roomId selon si géoloc a réussi)
    final id = const Uuid().v4();
    final clientMap = {
      'id': id,
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
      'lat': clientLat,
      'lng': clientLng,
      'waiting_room_id': roomId,
      'is_synced': 0,
    };
    
    // Insère localement d'abord
    await _localDb.insertClientLocally(clientMap);
    
    // Si on a un roomId, insère aussi dans Supabase
    if (roomId != null) {
      try {
        await _supabase.from('clients').insert({
          'name': name,
          'lat': clientLat,
          'lng': clientLng,
          'waiting_room_id': roomId,
        });
        // Marque comme synchronisé si l'insertion a réussi
        await _localDb.markClientAsSynced(id);
      } catch (e) {
        // Échec de sync - reste en local, sera sync plus tard
        // ignore: avoid_print
        print('Remote insert failed: $e');
      }
    }
    
    // Recharge depuis la base locale pour mettre à jour l'UI
    final rows = await _localDb.getClients();
    _clients = rows.map((m) => Client.fromMap(m)).toList();
    _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  Future<void> _seedLocalRoomsAndClients() async {
    final sampleRooms = [
      {
        'id': 'room1',
        'name': 'Salle Centre Ville',
        'latitude': 36.8065,
        'longitude': 10.1815,
      },
      {
        'id': 'room2',
        'name': 'Salle Lac 2',
        'latitude': 36.8480,
        'longitude': 10.2766,
      },
      {
        'id': 'room3',
        'name': 'Salle El Menzah',
        'latitude': 36.8390,
        'longitude': 10.1693,
      },
    ];

    for (final room in sampleRooms) {
      await _localDb.insertRoomLocally(room);
    }
    _rooms = sampleRooms;

    final sampleClients = [
      {
        'id': const Uuid().v4(),
        'name': 'Alice',
        'created_at': DateTime.now().toIso8601String(),
        'lat': null,
        'lng': null,
        'waiting_room_id': 'room1',
        'is_synced': 0,
      },
      {
        'id': const Uuid().v4(),
        'name': 'Bob',
        'created_at': DateTime.now().toIso8601String(),
        'lat': null,
        'lng': null,
        'waiting_room_id': 'room2',
        'is_synced': 0,
      },
      {
        'id': const Uuid().v4(),
        'name': 'Charlie',
        'created_at': DateTime.now().toIso8601String(),
        'lat': null,
        'lng': null,
        'waiting_room_id': 'room3',
        'is_synced': 0,
      },
    ];

    for (final c in sampleClients) {
      await _localDb.insertClientLocally(c);
    }

    final rows = await _localDb.getClients();
    _clients = rows.map((m) => Client.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> _seedRemoteRoomsAndClients() async {
    try {
      final rooms = [
        {
          'id': 'room1',
          'name': 'Salle Centre Ville',
          'latitude': 36.8065,
          'longitude': 10.1815,
        },
        {
          'id': 'room2',
          'name': 'Salle Lac 2',
          'latitude': 36.8480,
          'longitude': 10.2766,
        },
        {
          'id': 'room3',
          'name': 'Salle El Menzah',
          'latitude': 36.8390,
          'longitude': 10.1693,
        },
      ];

      try {
        await _supabase.from('waiting_rooms').insert(rooms);
      } catch (_) {}

      final clients = [
        {
          'name': 'Alice',
          'waiting_room_id': 'room1',
        },
        {
          'name': 'Bob',
          'waiting_room_id': 'room2',
        },
        {
          'name': 'Charlie',
          'waiting_room_id': 'room3',
        },
      ];

      try {
        await _supabase.from('clients').insert(clients);
      } catch (_) {}
    } catch (e) {
      // ignore
    }
  }

  /// Remove client locally and attempt remote delete.
  Future<void> removeClient(String id) async {
    try {
      await _localDb.deleteClient(id);
    } catch (e) {
      // ignore: avoid_print
      print('Local delete failed for $id: $e');
    }

    _clients.removeWhere((c) => c.id == id);
    notifyListeners();

    // Try remote delete
    try {
      final del = _supabase.from('clients').delete();
      // Many clients support `.match` for deleting by map, tests' fake uses match
      try {
        await del.match({'id': id});
      } catch (_) {
        // fallback to trying to await the builder directly (some fakes)
        try {
          await del;
        } catch (e) {
          // ignore
          // ignore: avoid_print
          print('Remote delete also failed for $id: $e');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Remote delete failed for $id: $e');
    }
  }

  /// Pops the next client and removes them (same as removeClient but returns the client)
  Future<Client?> nextClient() async {
    if (_clients.isEmpty) return null;
    final client = _clients.removeAt(0);
    notifyListeners();
    await removeClient(client.id);
    return client;
  }

  void _setupRealtimeSubscription() {
    // For now, skip realtime wiring — keep this stub so tests/consumers can
    // call it without failure. Realtime can be added later with proper
    // subscription lifecycle handling.
  }

  void subscribeToRoom(String roomId) {
    if (isTesting) return; // Skip en mode test
    
    // Annule l'ancienne souscription s'il y en a une
    try {
      _subscription?.unsubscribe();
    } catch (e) {
      // Ignore si déjà annulée
    }
    
    try {
      // Utiliser Realtime Channel avec filtre pour la salle spécifique
      final channel = _supabase.channel('room:$roomId');
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'clients',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'waiting_room_id',
          value: roomId,
        ),
        callback: (payload) {
          // Rafraîchir la liste quand il y a des changements
          _fetchRemoteClients(reset: true, roomId: roomId);
        },
      );
      _subscription = channel.subscribe();
    } catch (e) {
      // En cas d'erreur, on continue sans realtime
      // ignore: avoid_print
      print('Failed to subscribe to room $roomId: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> close() => _localDb.close();
}
