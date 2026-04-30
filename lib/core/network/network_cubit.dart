import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/reachability_service.dart';

enum NetworkStatus { initial, online, degraded, offline, syncing }

class NetworkCubit extends Cubit<NetworkStatus> {
  final ReachabilityService _reachabilityService;
  StreamSubscription<ReachabilitySnapshot>? _reachabilitySubscription;
  int _degradedStreak = 0;
  int _onlineStreak = 0;
  bool _syncingRequested = false;

  static const int _degradedThreshold = 2;
  static const int _recoveryThreshold = 2;

  NetworkCubit({ReachabilityService? reachabilityService})
    : _reachabilityService = reachabilityService ?? ReachabilityService(),
      super(NetworkStatus.initial) {
    _monitorConnectivity();
  }

  void _monitorConnectivity() {
    _reachabilitySubscription = _reachabilityService.stream.listen(
      _onReachabilityUpdate,
    );

    _reachabilityService.refresh();
  }

  void setSyncing(bool value) {
    _syncingRequested = value;
    if (value) {
      final snapshot = _reachabilityService.current;
      if (snapshot.hasNetworkInterface) {
        _emitIfChanged(NetworkStatus.syncing);
      }
      return;
    }

    _onReachabilityUpdate(_reachabilityService.current);
  }

  void _onReachabilityUpdate(ReachabilitySnapshot snapshot) {
    if (!snapshot.hasNetworkInterface) {
      _degradedStreak = 0;
      _onlineStreak = 0;
      _syncingRequested = false;
      _emitIfChanged(NetworkStatus.offline);
      return;
    }

    if (snapshot.serverReachable) {
      _onlineStreak += 1;
      _degradedStreak = 0;

      if (_syncingRequested) {
        _emitIfChanged(NetworkStatus.syncing);
        return;
      }

      if (state == NetworkStatus.degraded &&
          _onlineStreak < _recoveryThreshold) {
        return;
      }

      _emitIfChanged(NetworkStatus.online);
      return;
    }

    _degradedStreak += 1;
    _onlineStreak = 0;

    if (_syncingRequested) {
      if (_degradedStreak >= _degradedThreshold) {
        _syncingRequested = false;
        _emitIfChanged(NetworkStatus.degraded);
      }
      return;
    }

    if (state == NetworkStatus.offline || state == NetworkStatus.initial) {
      if (_degradedStreak >= _degradedThreshold) {
        _emitIfChanged(NetworkStatus.degraded);
      }
      return;
    }

    if (state == NetworkStatus.online &&
        _degradedStreak >= _degradedThreshold) {
      _emitIfChanged(NetworkStatus.degraded);
    }
  }

  void _emitIfChanged(NetworkStatus next) {
    if (state != next) {
      emit(next);
    }
  }

  @override
  Future<void> close() {
    _reachabilitySubscription?.cancel();
    return super.close();
  }
}
