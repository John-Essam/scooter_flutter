import 'package:flutter/services.dart';

class ScooterBridgeClient {
  ScooterBridgeClient();

  static const String _methodChannelName = 'scooter/bridge';
  final MethodChannel _bridge = const MethodChannel(_methodChannelName);

  Future<Map<String, dynamic>> startScan({int? timeoutMs}) =>
      _invoke('startScan', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> stopScan({int? timeoutMs}) =>
      _invoke('stopScan', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> connect({
    required String deviceId,
    int? timeoutMs,
  }) =>
      _invoke('connect', timeoutMs: timeoutMs, payload: {'deviceId': deviceId});
  Future<Map<String, dynamic>> bind({int? timeoutMs}) =>
      _invoke('bind', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> unbind({int? timeoutMs}) =>
      _invoke('unbind', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> disconnect({int? timeoutMs}) =>
      _invoke('disconnect', timeoutMs: timeoutMs);

  Future<Map<String, dynamic>> setLock({
    required bool locked,
    int? timeoutMs,
  }) => _invoke('setLock', timeoutMs: timeoutMs, payload: {'locked': locked});
  Future<Map<String, dynamic>> setCruiseControl({
    required bool enabled,
    int? timeoutMs,
  }) => _invoke(
    'setCruiseControl',
    timeoutMs: timeoutMs,
    payload: {'enabled': enabled},
  );
  Future<Map<String, dynamic>> setStartMode({
    required bool enabled,
    int? timeoutMs,
  }) => _invoke(
    'setStartMode',
    timeoutMs: timeoutMs,
    payload: {'enabled': enabled},
  );
  Future<Map<String, dynamic>> setUnitSystem({
    required bool metric,
    int? timeoutMs,
  }) => _invoke(
    'setUnitSystem',
    timeoutMs: timeoutMs,
    payload: {'metric': metric},
  );
  Future<Map<String, dynamic>> readThrottleResponse({int? timeoutMs}) =>
      _invoke('readThrottleResponse', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readBrakeResponse({int? timeoutMs}) =>
      _invoke('readBrakeResponse', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readControllerTemperature({int? timeoutMs}) =>
      _invoke('readControllerTemperature', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readBatteryTemperature({int? timeoutMs}) =>
      _invoke('readBatteryTemperature', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readMotorTemperature({int? timeoutMs}) =>
      _invoke('readMotorTemperature', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readDrivingCurrent({int? timeoutMs}) =>
      _invoke('readDrivingCurrent', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readRemainingMileage({int? timeoutMs}) =>
      _invoke('readRemainingMileage', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readTripMileage({int? timeoutMs}) =>
      _invoke('readTripMileage', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readOdo({int? timeoutMs}) =>
      _invoke('readOdo', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readSpeedStats({int? timeoutMs}) =>
      _invoke('readSpeedStats', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readSerialNumber({int? timeoutMs}) =>
      _invoke('readSerialNumber', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readDeviceInfo({int? timeoutMs}) =>
      _invoke('readDeviceInfo', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readMeterVersion({int? timeoutMs}) =>
      _invoke('readMeterVersion', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readControllerVersion({int? timeoutMs}) =>
      _invoke('readControllerVersion', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> setThrottleBrakeResponse({
    required int throttle,
    required int brake,
    int? timeoutMs,
  }) => _invoke(
    'setThrottleBrakeResponse',
    timeoutMs: timeoutMs,
    payload: {'throttle': throttle, 'brake': brake},
  );
  Future<Map<String, dynamic>> readNfcStatus({int? timeoutMs}) =>
      _invoke('readNfcStatus', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> setNfcEnabled({
    required bool enabled,
    int? timeoutMs,
  }) => _invoke(
    'setNfcEnabled',
    timeoutMs: timeoutMs,
    payload: {'enabled': enabled},
  );
  Future<Map<String, dynamic>> factoryReset({int? timeoutMs}) =>
      _invoke('factoryReset', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> readGearMaxSpeed({
    required int gear,
    int? timeoutMs,
  }) => _invoke(
    'readGearMaxSpeed',
    timeoutMs: timeoutMs,
    payload: {'gear': gear},
  );
  Future<Map<String, dynamic>> setAmbientLight({
    required bool on,
    int? timeoutMs,
  }) => _invoke('setAmbientLight', timeoutMs: timeoutMs, payload: {'on': on});
  Future<Map<String, dynamic>> setAmbientRgb({
    required int mode,
    required int red,
    required int green,
    required int blue,
    int brightness = 255,
    int? timeoutMs,
  }) => _invoke(
    'setAmbientRgb',
    timeoutMs: timeoutMs,
    payload: {
      'mode': mode,
      'red': red,
      'green': green,
      'blue': blue,
      'brightness': brightness,
    },
  );
  Future<Map<String, dynamic>> setRainbowMode({int? timeoutMs}) =>
      _invoke('setRainbowMode', timeoutMs: timeoutMs);
  Future<Map<String, dynamic>> setGear({required int gear, int? timeoutMs}) =>
      _invoke('setGear', timeoutMs: timeoutMs, payload: {'gear': gear});
  Future<Map<String, dynamic>> setFrontLight({
    required bool on,
    int? timeoutMs,
  }) => _invoke('setFrontLight', timeoutMs: timeoutMs, payload: {'on': on});

  Future<Map<String, dynamic>> _invoke(
    String method, {
    Map<String, dynamic> payload = const {},
    int? timeoutMs,
  }) async {
    final args = <String, Object?>{'timeoutMs': timeoutMs, 'payload': payload};

    final raw = await _bridge.invokeMethod<Object?>(method, args);
    if (raw is! Map) {
      throw PlatformException(
        code: 'INTERNAL_ERROR',
        message: 'Native response is not a map',
      );
    }
    final normalized = raw.map((key, value) => MapEntry(key.toString(), value));
    if (normalized.containsKey('ok')) {
      final ok = normalized['ok'] == true;
      if (!ok) {
        final err = normalized['error'];
        if (err is Map) {
          final errorMap = err.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          throw PlatformException(
            code: (errorMap['code']?.toString()) ?? 'INTERNAL_ERROR',
            message: errorMap['message']?.toString(),
            details: errorMap['details'],
          );
        }
        throw PlatformException(
          code: 'INTERNAL_ERROR',
          message: 'Native error envelope is malformed',
        );
      }
      final data = normalized['data'];
      if (data is Map) {
        return data.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }
    return normalized;
  }
}
