import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_logger.dart';

/// App-wide connectivity awareness so Firebase-backed screens can show a
/// "you're offline" state instead of a raw exception, and automatically
/// recover (re-subscribe streams, retry pending writes) once the
/// connection returns.
///
/// Firestore already has its own offline cache/queue, so this isn't
/// about replacing that — it's about giving the UI a signal to react to
/// (banners, disabled submit buttons, "reconnecting..." states) and a
/// single place other services can await "is there a network right now".
class NetworkMonitor {
  NetworkMonitor._();
  static final NetworkMonitor instance = NetworkMonitor._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> start() async {
    if (_subscription != null) return;
    final initial = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(initial);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        AppLogger.info(online ? 'Network restored' : 'Network lost', tag: 'network');
        _controller.add(online);
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> checkNow() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    return _isOnline;
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
