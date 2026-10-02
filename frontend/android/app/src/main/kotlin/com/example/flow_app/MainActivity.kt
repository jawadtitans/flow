package com.example.flow_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow/security").setMethodCallHandler { call, result ->
            if (call.method == "secure") {
                if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else result.notImplemented()
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow/widget").setMethodCallHandler { call, result ->
            val manager = AppWidgetManager.getInstance(this)
            when (call.method) {
                "sdk" -> result.success(Build.VERSION.SDK_INT)
                "pinSupported" -> result.success(Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported)
                "pin" -> {
                    if (Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported) {
                        result.success(manager.requestPinAppWidget(ComponentName(this, FlowWidgetProvider::class.java), null, null))
                    } else result.error("unsupported", "Add the widget using your launcher widget picker.", null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
