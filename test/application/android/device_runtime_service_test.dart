import 'package:flutter_test/flutter_test.dart';
import '../../../lib/application/android/device_runtime_service.dart';
import '../../../lib/domain/android/device_runtime_state.dart';

void main() {
  test('device runtime follows start pause resume stop lifecycle', () {
    final service = DeviceRuntimeService();
    expect(service.state, DeviceRuntimeState.stopped);
    service.start();
    expect(service.state, DeviceRuntimeState.running);
    service.pause();
    expect(service.state, DeviceRuntimeState.paused);
    service.resume();
    expect(service.state, DeviceRuntimeState.running);
    service.stop();
    expect(service.state, DeviceRuntimeState.stopped);
  });
}
