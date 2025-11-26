import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  bool _isOnline = false;
  bool get isOnline => _isOnline;
  ConnectivityService() {
    // Initial check
    _checkConnectivity();
    // Subscribe to stream updates
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
  _updateConnectionStatus(
    results.contains(ConnectivityResult.none)
      ? ConnectivityResult.none
      : results.first
  );
});
  }
  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final status = results.contains(ConnectivityResult.none)
        ? ConnectivityResult.none
        : results.first;
    _updateConnectionStatus(status);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final newStatus = result != ConnectivityResult.none;
    if (_isOnline != newStatus) {
      _isOnline = newStatus;
      notifyListeners();
      // The QueueProvider will listen for this to trigger resync
    }
  }
}
