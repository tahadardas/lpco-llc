import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lpco_llc/features/products/application/camera_permission_coordinator.dart';

class FakeCameraPermissionGateway implements CameraPermissionGateway {
  PermissionStatus current;
  PermissionStatus requested;
  int requestCount = 0;
  int settingsCount = 0;

  FakeCameraPermissionGateway({required this.current, required this.requested});

  @override
  Future<bool> openSettings() async {
    settingsCount++;
    return true;
  }

  @override
  Future<PermissionStatus> request() async {
    requestCount++;
    current = requested;
    return requested;
  }

  @override
  Future<PermissionStatus> status() async => current;
}

void main() {
  test('requests the native permission after an initial denial', () async {
    final gateway = FakeCameraPermissionGateway(
      current: PermissionStatus.denied,
      requested: PermissionStatus.granted,
    );
    final coordinator = CameraPermissionCoordinator(gateway: gateway);

    expect(await coordinator.request(), CameraPermissionState.granted);
    expect(gateway.requestCount, 1);
  });

  test('does not request again after permanent denial', () async {
    final gateway = FakeCameraPermissionGateway(
      current: PermissionStatus.permanentlyDenied,
      requested: PermissionStatus.granted,
    );
    final coordinator = CameraPermissionCoordinator(gateway: gateway);

    expect(
      await coordinator.request(),
      CameraPermissionState.permanentlyDenied,
    );
    expect(gateway.requestCount, 0);
    expect(await coordinator.openSettings(), isTrue);
    expect(gateway.settingsCount, 1);
  });

  test('inspect reflects a grant made in device settings', () async {
    final gateway = FakeCameraPermissionGateway(
      current: PermissionStatus.denied,
      requested: PermissionStatus.denied,
    );
    final coordinator = CameraPermissionCoordinator(gateway: gateway);
    expect(await coordinator.inspect(), CameraPermissionState.denied);

    gateway.current = PermissionStatus.granted;
    expect(await coordinator.inspect(), CameraPermissionState.granted);
  });
}
