package com.example.eyeon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "eyeon_native_camera",
            NativeCameraViewFactory(flutterEngine.dartExecutor.binaryMessenger, this)
        )
    }
}
