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

  String _nextRequestId() {
    _reqCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_reqCounter';
  }
}
