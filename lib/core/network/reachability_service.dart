import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:lpco_llc/core/config/app_config.dart';

enum ReachabilityStatus { unknown, offline, networkOnly, online }

class ReachabilitySnapshot {
  final ReachabilityStatus status;
  final bool hasNetworkInterface;
  final bool serverReachable;
  final DateTime checkedAt;

  const ReachabilitySnapshot({
    required this.status,
    required this.hasNetworkInterface,
    required this.serverReachable,
    required this.checkedAt,
  });

  bool get isOnline => status == ReachabilityStatus.online;
}

class ReachabilityService {
  static final ReachabilityService _instance = ReachabilityService._internal();
  factory ReachabilityService() => _instance;
  ReachabilityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ReachabilitySnapshot> _controller = StreamController<ReachabilitySnapshot>.broadcast();

  Dio? _probeDio;
  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _initialized = false;

  ReachabilitySnapshot _current = ReachabilitySnapshot(
    status: ReachabilityStatus.unknown,
    hasNetworkInterface: false,
    serverReachable: false,
    checkedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  DateTime? _lastCheckTime;
  static const Duration _cacheTtl = Duration(seconds: 30);
  static const Duration _offlineProbeInterval = Duration(minutes: 5);
  static const Duration _onlineProbeInterval = Duration(minutes: 15);

  ReachabilitySnapshot get current => _current;
  Stream<ReachabilitySnapshot> get stream => _controller.stream;

  Future<void> initialize({Dio? probeDio}) async {
    if (_initialized) return;

    _probeDio = probeDio ?? _buildProbeDio();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasInterface = !results.contains(ConnectivityResult.none);
      if (!hasInterface) {
        _updateStatus(ReachabilityStatus.offline, false, false);
      } else {
        refresh(force: true);
      }
    });

    _startTimer();
    _initialized = true;
    await refresh(force: true);
  }

  void _startTimer() {
    _periodicTimer?.cancel();
    final interval = _current.status == ReachabilityStatus.online 
        ? _onlineProbeInterval 
        : _offlineProbeInterval;
    _periodicTimer = Timer.periodic(interval, (_) => refresh());
  }

  Future<ReachabilitySnapshot> refresh({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastCheckTime != null && now.difference(_lastCheckTime!) < _cacheTtl) {
      return _current;
    }

    _lastCheckTime = now;
    final results = await _connectivity.checkConnectivity();
    final hasInterface = !results.contains(ConnectivityResult.none);

    if (!hasInterface) {
      return _updateStatus(ReachabilityStatus.offline, false, false);
    }

    // Only probe if we really need to know the state
    final reachable = await _probeServerReachability();
    return _updateStatus(
      reachable ? ReachabilityStatus.online : ReachabilityStatus.networkOnly,
      true,
      reachable,
    );
  }

  ReachabilitySnapshot _updateStatus(ReachabilityStatus status, bool interface, bool reachable) {
    _current = ReachabilitySnapshot(
      status: status,
      hasNetworkInterface: interface,
      serverReachable: reachable,
      checkedAt: DateTime.now().toUtc(),
    );
    _controller.add(_current);
    return _current;
  }

  Dio _buildProbeDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.wpApiBase,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        headers: const {'Accept': 'application/json'},
      ),
    );
  }

  Future<bool> _probeServerReachability() async {
    try {
      final response = await _probeDio?.get(
        '/',
        options: Options(
          extra: const {'skipAuth': true},
          validateStatus: (status) => status != null,
        ),
      );
      return (response?.statusCode ?? 0) > 0 && (response?.statusCode ?? 0) < 500;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
    await _controller.close();
    _initialized = false;
  }
}
