package com.foxrunmobility.rider
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val channel = "com.foxrunmobility.rider/razorpay_upi_intent"
    private val tag = "RazorpayUPI"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "initRazorpayUpiIntent" -> {
                    // The full native UPI Intent SDK binding (Razorpay constructor + forwarding
                    // onActivityResult) is intentionally not active in this build since the
                    // proprietary UPI Intent SDK artifact isn't bundled here.
                    //
                    // We keep the MethodChannel so the Flutter WebView flow remains uninterrupted.
                    Log.d(tag, "initRazorpayUpiIntent called (no-op)")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
