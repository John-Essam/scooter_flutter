package com.example.scooter_bridge_arch

import com.example.scooter_android_demo.channel.ScooterMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bridgeChannel: ScooterMethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridgeChannel = ScooterMethodChannel(
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            context = applicationContext,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridgeChannel?.dispose()
        bridgeChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
