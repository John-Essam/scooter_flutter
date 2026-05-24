import 'package:flutter/material.dart';

import '../bridge/scooter_bridge_client.dart';
import 'scooter_home_screen.dart';

class BridgeConsolePage extends StatefulWidget {
  const BridgeConsolePage({super.key});

  @override
  State<BridgeConsolePage> createState() => _BridgeConsolePageState();
}

class _BridgeConsolePageState extends State<BridgeConsolePage> {
  final ScooterBridgeClient _bridge = ScooterBridgeClient();
  final TextEditingController _deviceIdController = TextEditingController();
  final List<String> _logs = <String>[];

  String _connectionState = 'idle';
  String? _connectedDeviceId;
  bool _isScanning = false;
  final int _batteryPercent = 80;
  bool _lockStatus = true;
  int _gear = 0;
  bool _headlightOn = false;
  bool _cruiseEnabled = false;
  bool _isUpdatingLock = false;
  bool _isUpdatingGear = false;
  bool _isUpdatingHeadlight = false;
  bool _isUpdatingCruise = false;

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _call(
    Future<Map<String, dynamic>> Function() action,
    String label,
  ) async {
    try {
      final response = await action();
      _append('$label -> $response');
    } catch (e) {
      _append('$label -> ERROR $e');
    }
  }

  void _append(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '${DateTime.now().toIso8601String()}  $message');
      if (_logs.length > 180) {
        _logs.removeRange(180, _logs.length);
      }
    });
  }

  int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _startScan() async {
    await _call(() => _bridge.startScan(), 'startScan');
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _connectionState = 'scanning';
    });
  }

  Future<void> _stopScan() async {
    await _call(() => _bridge.stopScan(), 'stopScan');
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      if (_connectionState == 'scanning') {
        _connectionState = 'idle';
      }
    });
  }

  Future<void> _connectTypedDevice() async {
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      _append('connect -> ERROR device id is required');
      return;
    }
    try {
      final response = await _bridge.connect(deviceId: deviceId);
      _append('connect($deviceId) -> $response');
      if (!mounted) return;
      setState(() {
        _connectedDeviceId = response['deviceId']?.toString() ?? deviceId;
        _connectionState = response['state']?.toString() ?? 'connected';
        _isScanning = false;
      });
    } catch (e) {
      _append('connect($deviceId) -> ERROR $e');
    }
  }

  Future<void> _disconnectFromDashboard() async {
    try {
      final response = await _bridge.disconnect();
      _append('disconnect -> $response');
    } catch (e) {
      _append('disconnect -> ERROR $e');
    }
    if (!mounted) return;
    setState(() {
      _connectionState = 'idle';
      _connectedDeviceId = null;
      _isScanning = false;
    });
  }

  Future<void> _setLock(bool locked) async {
    if (_isUpdatingLock) return;
    setState(() {
      _isUpdatingLock = true;
    });
    try {
      final response = await _bridge.setLock(locked: locked);
      final lockValue = response['lockStatus'];
      if (mounted && lockValue is bool) {
        setState(() {
          _lockStatus = lockValue;
        });
      }
      _append('setLock($locked) -> $response');
    } catch (e) {
      _append('setLock($locked) -> ERROR $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLock = false;
        });
      }
    }
  }

  Future<void> _setGear(int gear) async {
    if (_isUpdatingGear) return;
    setState(() {
      _isUpdatingGear = true;
    });
    try {
      final response = await _bridge.setGear(gear: gear);
      final gearValue = _toInt(response['gear']);
      if (mounted && gearValue != null) {
        setState(() {
          _gear = gearValue.clamp(0, 3);
        });
      }
      _append('setGear($gear) -> $response');
    } catch (e) {
      _append('setGear($gear) -> ERROR $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingGear = false;
        });
      }
    }
  }

  Future<void> _setHeadlight(bool on) async {
    if (_isUpdatingHeadlight) return;
    setState(() {
      _isUpdatingHeadlight = true;
    });
    try {
      final response = await _bridge.setFrontLight(on: on);
      final value = response['frontLightOn'];
      if (mounted && value is bool) {
        setState(() {
          _headlightOn = value;
        });
      }
      _append('setFrontLight($on) -> $response');
    } catch (e) {
      _append('setFrontLight($on) -> ERROR $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingHeadlight = false;
        });
      }
    }
  }

  Future<void> _setCruiseControl(bool enabled) async {
    if (_isUpdatingCruise) return;
    setState(() {
      _isUpdatingCruise = true;
    });
    try {
      final response = await _bridge.setCruiseControl(enabled: enabled);
      final value = response['cruiseControl'];
      if (mounted && value is bool) {
        setState(() {
          _cruiseEnabled = value;
        });
      }
      _append('setCruiseControl($enabled) -> $response');
    } catch (e) {
      _append('setCruiseControl($enabled) -> ERROR $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCruise = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connectedDeviceId != null && _connectionState == 'connected') {
      return ScooterHomeScreen(
        deviceId: _connectedDeviceId!,
        batteryPercent: _batteryPercent,
        isLocked: _lockStatus,
        currentGear: _gear,
        headlightOn: _headlightOn,
        cruiseEnabled: _cruiseEnabled,
        isUpdatingLock: _isUpdatingLock,
        isUpdatingGear: _isUpdatingGear,
        isUpdatingHeadlight: _isUpdatingHeadlight,
        isUpdatingCruise: _isUpdatingCruise,
        onToggleLock: _setLock,
        onSetGear: _setGear,
        onSetHeadlight: _setHeadlight,
        onSetCruiseControl: _setCruiseControl,
        onDisconnect: _disconnectFromDashboard,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scooter Bridge Console')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Scooter device id (MAC)',
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _startScan,
                child: const Text('Start Scan'),
              ),
              ElevatedButton(
                onPressed: _stopScan,
                child: const Text('Stop Scan'),
              ),
              ElevatedButton(
                onPressed: _connectTypedDevice,
                child: const Text('Connect'),
              ),
              ElevatedButton(
                onPressed: _disconnectFromDashboard,
                child: const Text('Disconnect'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Connection: $_connectionState'
                '${_connectedDeviceId != null ? ' ($_connectedDeviceId)' : ''}'
                '${_isScanning ? ' (scanning...)' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(_logs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
