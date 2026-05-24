import 'package:flutter/services.dart';

import 'bridge_error.dart';
import 'bridge_response.dart';
import 'channel_names.dart';

class ScooterBridgeClient {
  ScooterBridgeClient();

  final MethodChannel _connection = const MethodChannel(
    ScooterChannels.connectionMethod,
  );
  final MethodChannel _control = const MethodChannel(ScooterChannels.controlMethod);

  final EventChannel _telemetry = const EventChannel(ScooterChannels.telemetryEvent);
  final EventChannel _connectionState = const EventChannel(
    ScooterChannels.connectionStateEvent,
  );
  final EventChannel _logs = const EventChannel(ScooterChannels.logsEvent);

  int _reqCounter = 0;

  Stream<Map<String, dynamic>> telemetryStream() => _mapEvent(_telemetry);
  Stream<Map<String, dynamic>> faultFlagsStream() => telemetryStream()
      .where((event) => _faultDataFromEvent(event) != null)
      .map((event) => _faultDataFromEvent(event)!);
  Stream<Map<String, dynamic>> operationalStatusStream() => telemetryStream()
      .where((event) => _operationalDataFromEvent(event) != null)
      .map((event) => _operationalDataFromEvent(event)!);
  Stream<Map<String, dynamic>> connectionStateStream() =>
      _mapEvent(_connectionState);
  Stream<Map<String, dynamic>> logsStream() => _mapEvent(_logs);

  Future<BridgeResponse> startScan({int? timeoutMs}) =>
      _invoke(_connection, 'startScan', timeoutMs: timeoutMs);
  Future<BridgeResponse> stopScan({int? timeoutMs}) =>
      _invoke(_connection, 'stopScan', timeoutMs: timeoutMs);
  Future<BridgeResponse> connect({required String deviceId, int? timeoutMs}) =>
      _invoke(
        _connection,
        'connect',
        timeoutMs: timeoutMs,
        payload: {'deviceId': deviceId},
      );
  Future<BridgeResponse> bind({int? timeoutMs}) =>
      _invoke(_connection, 'bind', timeoutMs: timeoutMs);
  Future<BridgeResponse> unbind({int? timeoutMs}) =>
      _invoke(_connection, 'unbind', timeoutMs: timeoutMs);
  Future<BridgeResponse> disconnect({int? timeoutMs}) =>
      _invoke(_connection, 'disconnect', timeoutMs: timeoutMs);

  Future<BridgeResponse> setLock({required bool locked, int? timeoutMs}) =>
      _invoke(
        _control,
        'setLock',
        timeoutMs: timeoutMs,
        payload: {'locked': locked},
      );
  Future<BridgeResponse> setCruiseControl({
    required bool enabled,
    int? timeoutMs,
  }) => _invoke(
    _control,
    'setCruiseControl',
    timeoutMs: timeoutMs,
    payload: {'enabled': enabled},
  );
  Future<BridgeResponse> setStartMode({
    required bool enabled,
    int? timeoutMs,
  }) => _invoke(
    _control,
    'setStartMode',
    timeoutMs: timeoutMs,
    payload: {'enabled': enabled},
  );
  Future<BridgeResponse> setUnitSystem({
    required bool metric,
    int? timeoutMs,
  }) => _invoke(
    _control,
    'setUnitSystem',
    timeoutMs: timeoutMs,
    payload: {'metric': metric},
  );
  Future<BridgeResponse> readThrottleResponse({int? timeoutMs}) => _invoke(
    _control,
    'readThrottleResponse',
    timeoutMs: timeoutMs,
  );
  Future<BridgeResponse> readBrakeResponse({int? timeoutMs}) => _invoke(
    _control,
    'readBrakeResponse',
    timeoutMs: timeoutMs,
  );
  Future<BridgeResponse> readControllerTemperature({int? timeoutMs}) => _invoke(
    _control,
    'readControllerTemperature',
    timeoutMs: timeoutMs,
  );
  Future<BridgeResponse> setThrottleBrakeResponse({
    required int throttle,
    required int brake,
    int? timeoutMs,
  }) => _invoke(
    _control,
    'setThrottleBrakeResponse',
    timeoutMs: timeoutMs,
    payload: {'throttle': throttle, 'brake': brake},
  );
  Future<BridgeResponse> readNfcStatus({int? timeoutMs}) => _invoke(
    _control,
    'readNfcStatus',
    timeoutMs: timeoutMs,
  );
  Future<BridgeResponse> setNfcEnabled({
    required bool enabled,
    int? timeoutMs,
  }) => _invoke(
    _control,
    'setNfcEnabled',
    timeoutMs: timeoutMs,
    payload: {'enabled': enabled},
  );
  Future<BridgeResponse> setAmbientLight({
    required bool on,
    int? timeoutMs,
  }) => _invoke(
    _control,
    'setAmbientLight',
    timeoutMs: timeoutMs,
    payload: {'on': on},
  );
  Future<BridgeResponse> setAmbientRgb({
    required int mode,
    required int red,
    required int green,
    required int blue,
    int brightness = 255,
    int? timeoutMs,
  }) => _invoke(
    _control,
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
  Future<BridgeResponse> setRainbowMode({int? timeoutMs}) => _invoke(
    _control,
    'setRainbowMode',
    timeoutMs: timeoutMs,
  );
  Future<BridgeResponse> setGear({required int gear, int? timeoutMs}) => _invoke(
    _control,
    'setGear',
    timeoutMs: timeoutMs,
    payload: {'gear': gear},
  );
  Future<BridgeResponse> setFrontLight({required bool on, int? timeoutMs}) =>
      _invoke(
        _control,
        'setFrontLight',
        timeoutMs: timeoutMs,
        payload: {'on': on},
      );

  Future<BridgeResponse> _invoke(
    MethodChannel channel,
    String method, {
    Map<String, dynamic> payload = const {},
    int? timeoutMs,
  }) async {
    final requestId = _nextRequestId();
    final args = <String, Object?>{
      'requestId': requestId,
      'timeoutMs': timeoutMs,
      'payload': payload,
    };

    final raw = await channel.invokeMethod<Object?>(method, args);
    if (raw is! Map) {
      throw BridgeException(
        code: 'INTERNAL_ERROR',
        message: 'Native response is not a map',
        retriable: false,
      );
    }

    final envelope = raw as JsonMap;
    final ok = (envelope['ok'] as bool?) ?? false;
    if (!ok) {
      final errMap = envelope['error'];
      if (errMap is Map) {
        throw BridgeException.fromErrorMap(errMap as JsonMap);
      }
      throw BridgeException(
        code: 'INTERNAL_ERROR',
        message: 'Native error envelope is malformed',
        retriable: false,
      );
    }

    return BridgeResponse.fromMap(envelope);
  }

  Stream<Map<String, dynamic>> _mapEvent(EventChannel channel) {
    return channel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{
        'type': 'raw',
        'timestampMs': DateTime.now().millisecondsSinceEpoch,
        'data': event,
      };
    });
  }

  Map<String, dynamic>? _faultDataFromEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final data = event['data'];
    if (data is! Map) return null;
    final normalized = data.map((key, value) => MapEntry(key.toString(), value));
    if (type == 'faultFlags') return normalized;
    if (type == 'heartbeat' && normalized['faults'] is Map) {
      final faults = (normalized['faults'] as Map)
          .map((key, value) => MapEntry(key.toString(), value));
      return faults;
    }
    return null;
  }

  Map<String, dynamic>? _operationalDataFromEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final data = event['data'];
    if (data is! Map) return null;
    final normalized = data.map((key, value) => MapEntry(key.toString(), value));
    if (type == 'operationalStatus') return normalized;
    if (type == 'heartbeat') {
      return {
        'lockStatus': normalized['lockStatus'],
        'headlightOn': normalized['headlightOn'],
        'cruiseEnabled': normalized['cruiseEnabled'],
        'cruiseActive': normalized['cruiseActive'],
        'startMode': normalized['startMode'],
        'gear': normalized['gear'],
        'metricUnit': normalized['metricUnit'],
        'charging': normalized['charging'],
        'motorRunning': normalized['motorRunning'],
        'electronicBrake': normalized['electronicBrake'],
        'mechanicalBrake': normalized['mechanicalBrake'],
      };
    }
    return null;
  }

  String _nextRequestId() {
    _reqCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_reqCounter';
  }
}
