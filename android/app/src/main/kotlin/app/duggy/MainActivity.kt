package app.duggy

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SHARE_CHANNEL = "app.duggy/share"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedData" -> {
                    val sharedData = getSharedData(intent)
                    result.success(sharedData)
                }
                else -> result.notImplemented()
            }
        }
        
        // Handle intent when app is launched via sharing
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle intent when app is already running and receives sharing
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND) {
            val sharedData = getSharedData(intent)
            if (sharedData != null) {
                // Send shared data to Flutter via method channel
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARE_CHANNEL)
                    .invokeMethod("onDataReceived", sharedData)
            }
        }
    }
    
    private fun getSharedData(intent: Intent?): Map<String, Any?>? {
        if (intent?.action == Intent.ACTION_SEND) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            
            return mapOf(
                "text" to text,
                "subject" to subject,
                "type" to "text"
            )
        }
        return null
    }
}
