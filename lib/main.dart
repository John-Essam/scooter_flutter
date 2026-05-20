import 'dart:async';

import 'package:flutter/material.dart';

import 'bridge/scooter_bridge_client.dart';
import 'screens/scooter_home_screen.dart';

void main() {
  runApp(const ScooterBridgeApp());
}

class ScooterBridgeApp extends StatelessWidget {
  const ScooterBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scooter Bridge Architecture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005B4F)),
        fontFamily: 'Cairo',
      ),
      home: const BridgeConsolePage(),
    );
  }
}

class BridgeConsolePage extends StatefulWidget {
  const BridgeConsolePage({super.key});

  @override
  State<BridgeConsolePage> createState() => _BridgeConsolePageState();
}

class _BridgeConsolePageState extends State<BridgeConsolePage> {
  final ScooterBridgeClient _bridge = ScooterBridgeClient();
  final List<String> _logs = <String>[];
  final List<_DiscoveredDevice> _scanDevices = <_DiscoveredDevice>[];
  String? _selectedDeviceId;
  String _connectionState = 'idle';
  String? _connectedDeviceId;
  bool _isScanning = false;
  int _batteryPercent = 80;
  bool _lockStatus = true;
  bool _isUpdatingLock = false;
  int _rxLogCounter = 0;
  String? _lastConnectionLog;
  StreamSubscription<Map<String, dynamic>>? _telemetrySub;
  StreamSubscription<Map<String, dynamic>>? _connectionSub;
  StreamSubscription<Map<String, dynamic>>? _nativeLogSub;
  StreamSubscription<Map<String, dynamic>>? _otaSub;

  @override
  void initState() {
    super.initState();
    _connectionSub = _bridge.connectionStateStream().listen((event) {
      _handleConnectionEvent(event);
    });
    _telemetrySub = _bridge.telemetryStream().listen((event) {
      final type = event['type'] ?? 'unknown';
      final data = event['data'];
      if (type == 'heartbeat' && data is Map) {
        final battery = _toInt(data['batteryPercent']);
        final lockStatus = data['lockStatus'];
        if (mounted && (battery != null || lockStatus is bool)) {
          setState(() {
            if (battery != null) {
              _batteryPercent = battery.clamp(0, 100);
            }
            if (lockStatus is bool) {
              _lockStatus = lockStatus;
            }
          });
        }
      }
      _append('[telemetry:$type] $data');
    });
    _nativeLogSub = _bridge.logsStream().listen((event) {
      final category = event['category'] ?? 'native';
      final message = event['message'] ?? event.toString();
      if (category == 'rx') {
        _rxLogCounter += 1;
        if (_rxLogCounter % 10 != 0) {
          return;
        }
      }
      _append('[native:$category] $message');
    });
    _otaSub = _bridge.otaProgressStream().listen((event) {
      _append('[ota] $event');
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _connectionSub?.cancel();
    _nativeLogSub?.cancel();
    _otaSub?.cancel();
    super.dispose();
  }

  Future<void> _call(Future<dynamic> Function() action, String label) async {
    try {
      final response = await action();
      _append('$label -> ${response.data}');
    } catch (e) {
      _append('$label -> ERROR $e');
    }
  }

  void _handleConnectionEvent(Map<String, dynamic> event) {
    final state = event['state']?.toString();
    final device = event['device']?.toString();
    final rawScanResults = event['scanResults'];
    final parsedScanResults = <_DiscoveredDevice>[];
    if (rawScanResults is List) {
      for (final item in rawScanResults) {
        if (item is Map) {
          parsedScanResults.add(
            _DiscoveredDevice(
              deviceId: item['deviceId']?.toString() ?? '',
              name: item['name']?.toString() ?? 'Unknown',
              model: item['model']?.toString() ?? 'Unknown',
              rssi: (item['rssi'] is num) ? (item['rssi'] as num).toInt() : 0,
            ),
          );
        }
      }
    }

    if (!mounted) return;
    setState(() {
      if (state != null) {
        _connectionState = state;
        _isScanning = state == 'scanning';
      }
      if (device != null && device.isNotEmpty) {
        _connectedDeviceId = device;
      } else if (state == 'idle' || state == 'error') {
        _connectedDeviceId = null;
      }
      if (parsedScanResults.isNotEmpty || _isScanning) {
        _scanDevices
          ..clear()
          ..addAll(parsedScanResults);
        if (_selectedDeviceId == null ||
            _scanDevices.every((d) => d.deviceId != _selectedDeviceId)) {
          _selectedDeviceId = _scanDevices.isNotEmpty
              ? _scanDevices.first.deviceId
              : null;
        }
      }
    });

    final compact = <String>[
      'state=$state',
      if (device != null) 'device=$device',
      if (parsedScanResults.isNotEmpty) 'scanCount=${parsedScanResults.length}',
      if (event['reason'] != null) 'reason=${event['reason']}',
    ].join(' ');
    if (compact != _lastConnectionLog) {
      _lastConnectionLog = compact;
      _append('[connection] $compact');
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

  Future<void> _toggleLock(bool locked) async {
    if (_isUpdatingLock) return;
    setState(() {
      _isUpdatingLock = true;
    });
    try {
      final response = await _bridge.setLock(locked: locked);
      final lockValue = response.data['lockStatus'];
      if (mounted && lockValue is bool) {
        setState(() {
          _lockStatus = lockValue;
        });
      }
      _append('setLock($locked) -> ${response.data}');
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

  Future<void> _disconnectFromDashboard() async {
    try {
      final response = await _bridge.disconnect();
      _append('disconnect -> ${response.data}');
    } catch (e) {
      _append('disconnect -> ERROR $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connectedDeviceId != null && _connectionState == 'connected') {
      return ScooterHomeScreen(
        deviceId: _connectedDeviceId!,
        batteryPercent: _batteryPercent,
        isLocked: _lockStatus,
        isUpdatingLock: _isUpdatingLock,
        onToggleLock: _toggleLock,
        onDisconnect: _disconnectFromDashboard,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scooter Bridge Console')),
      body: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _call(() => _bridge.startScan(), 'startScan'),
                child: const Text('Start Scan'),
              ),
              ElevatedButton(
                onPressed: () => _call(() => _bridge.stopScan(), 'stopScan'),
                child: const Text('Stop Scan'),
              ),
              ElevatedButton(
                onPressed: _selectedDeviceId == null
                    ? null
                    : () => _call(
                        () => _bridge.connect(deviceId: _selectedDeviceId!),
                        'connect(${_selectedDeviceId!})',
                      ),
                child: const Text('Connect'),
              ),
              ElevatedButton(
                onPressed: () =>
                    _call(() => _bridge.disconnect(), 'disconnect'),
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
                '${_connectedDeviceId != null ? ' ($_connectedDeviceId)' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Discovered scooters: ${_scanDevices.length}'
                '${_isScanning ? ' (scanning...)' : ''}',
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: _scanDevices.isEmpty
                ? const Center(
                    child: Text('No scooter devices yet. Tap Start Scan.'),
                  )
                : ListView.builder(
                    itemCount: _scanDevices.length,
                    itemBuilder: (context, index) {
                      final device = _scanDevices[index];
                      final selected = device.deviceId == _selectedDeviceId;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        title: Text('${device.name} (${device.model})'),
                        subtitle: Text(
                          'id=${device.deviceId}  RSSI=${device.rssi}',
                        ),
                        onTap: () {
                          setState(() {
                            _selectedDeviceId = device.deviceId;
                          });
                          _append(
                            '[ui] selected device ${device.deviceId} (${device.name})',
                          );
                        },
                      );
                    },
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

class _DiscoveredDevice {
  const _DiscoveredDevice({
    required this.deviceId,
    required this.name,
    required this.model,
    required this.rssi,
  });

  final String deviceId;
  final String name;
  final String model;
  final int rssi;
}
