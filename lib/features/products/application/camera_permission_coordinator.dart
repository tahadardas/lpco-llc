import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionState {
  checking,
  granted,
  denied,
  permanentlyDenied,
  restricted,
  failed,
}

abstract class CameraPermissionGateway {
  Future<PermissionStatus> status();
  Future<PermissionStatus> request();
  Future<bool> openSettings();
}

class PermissionHandlerCameraGateway implements CameraPermissionGateway {
  const PermissionHandlerCameraGateway();

  @override
  Future<PermissionStatus> status() => Permission.camera.status;

  @override
  Future<PermissionStatus> request() => Permission.camera.request();

  @override
  Future<bool> openSettings() => openAppSettings();
}

class CameraPermissionCoordinator {
  final CameraPermissionGateway _gateway;

  const CameraPermissionCoordinator({CameraPermissionGateway? gateway})
    : _gateway = gateway ?? const PermissionHandlerCameraGateway();

  Future<CameraPermissionState> inspect() async {
    return _map(await _gateway.status());
  }

  Future<CameraPermissionState> request() async {
    final current = await inspect();
    if (current == CameraPermissionState.granted ||
        current == CameraPermissionState.permanentlyDenied ||
        current == CameraPermissionState.restricted) {
      return current;
    }
    return _map(await _gateway.request());
  }

  Future<bool> openSettings() => _gateway.openSettings();

  CameraPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return CameraPermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return CameraPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) {
      return CameraPermissionState.restricted;
    }
    return CameraPermissionState.denied;
  }
}
