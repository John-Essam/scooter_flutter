import 'package:flutter/material.dart';

import 'ui/bridge_console_page.dart';

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
