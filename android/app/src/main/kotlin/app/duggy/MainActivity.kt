package app.duggy

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val SHARE_CHANNEL = "app.duggy/share"
    private val CLIPBOARD_CHANNEL = "app.duggy/clipboard"
    
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
        
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CLIPBOARD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getClipboardImage" -> {
                    val allowedMimeTypes = (call.arguments as? Map<String, Any>)?.get("allowedMimeTypes") as? List<String> ?: emptyList()
                    getClipboardImage(result, allowedMimeTypes)
                }
                "getClipboardImageSafe" -> {
                    val allowedMimeTypes = (call.arguments as? Map<String, Any>)?.get("allowedMimeTypes") as? List<String> ?: emptyList()
                    getClipboardImageSafe(result, allowedMimeTypes)
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
    
    private fun getClipboardImage(result: MethodChannel.Result, allowedMimeTypes: List<String>) {
        try {
            println("📋 Android getClipboardImage method called with MIME types: $allowedMimeTypes")
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

            println("📋 Has primary clip: ${clipboard.hasPrimaryClip()}")

            if (clipboard.hasPrimaryClip()) {
                val clip = clipboard.primaryClip
                val description = clip?.description
                println("📋 Clip description: $description")

                // Check if clipboard contains allowed MIME types
                if (allowedMimeTypes.isNotEmpty() && description != null) {
                    val clipMimeTypes = (0 until description.mimeTypeCount).map { description.getMimeType(it) }
                    println("📋 Available MIME types: $clipMimeTypes")

                    val hasAllowedType = clipMimeTypes.any { clipType ->
                        allowedMimeTypes.any { allowedType ->
                            clipType.startsWith(allowedType.substringBefore('*')) ||
                            clipType == allowedType
                        }
                    }

                    if (!hasAllowedType) {
                        println("📋 No allowed MIME types found in clipboard")
                        result.success(null)
                        return
                    }

                    println("📋 Found allowed MIME type in clipboard")
                }

                if (clip != null && clip.itemCount > 0) {
                    val item = clip.getItemAt(0)
                    println("📋 Item text: ${item.text}")
                    println("📋 Item URI: ${item.uri}")
                    println("📋 Item HTML text: ${item.htmlText}")

                    val uri = item.uri

                    if (uri != null) {
                        try {
                            println("📋 Processing URI: $uri")
                            val inputStream = contentResolver.openInputStream(uri)
                            val drawable = Drawable.createFromStream(inputStream, uri.toString())

                            if (drawable is BitmapDrawable) {
                                val bitmap = drawable.bitmap
                                val stream = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                val byteArray = stream.toByteArray()

                                println("📋 Found valid image in Android clipboard, size: ${byteArray.size} bytes")
                                result.success(byteArray)
                                return
                            } else {
                                println("❌ Drawable is not BitmapDrawable: ${drawable?.javaClass?.simpleName}")
                            }
                        } catch (e: Exception) {
                            println("❌ Error processing clipboard image: ${e.message}")
                            e.printStackTrace()
                        }
                    } else {
                        println("📋 Item URI is null")
                    }
                } else {
                    println("📋 Clip is null or has no items")
                }
            }

            println("📋 No valid image found in Android clipboard")
            result.success(null)
        } catch (e: Exception) {
            println("❌ Error accessing Android clipboard: ${e.message}")
            e.printStackTrace()
            result.error("CLIPBOARD_ERROR", e.message, null)
        }
    }

    private fun getClipboardImageSafe(result: MethodChannel.Result, allowedMimeTypes: List<String>) {
        try {
            println("📋 Android getClipboardImageSafe method called with MIME types: $allowedMimeTypes")
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

            println("📋 Has primary clip: ${clipboard.hasPrimaryClip()}")

            if (!clipboard.hasPrimaryClip()) {
                println("📋 No primary clip available")
                result.success(null)
                return
            }

            val clip = clipboard.primaryClip
            val description = clip?.description

            println("📋 Clip description: $description")

            // Check mime types to see if there might be an allowed image without accessing content
            val availableMimeTypes = description?.let { desc ->
                (0 until desc.mimeTypeCount).map { desc.getMimeType(it) }
            } ?: emptyList()

            println("📋 Available MIME types: $availableMimeTypes")

            // If allowedMimeTypes is specified, check against them
            val hasAllowedImageMimeType = if (allowedMimeTypes.isNotEmpty()) {
                availableMimeTypes.any { availableType ->
                    allowedMimeTypes.any { allowedType ->
                        availableType.startsWith(allowedType.substringBefore('*')) ||
                        availableType == allowedType
                    }
                }
            } else {
                // Fallback to any image type if no specific types allowed
                availableMimeTypes.any { it.startsWith("image/") }
            }

            if (!hasAllowedImageMimeType) {
                println("📋 No allowed image MIME types found")
                result.success(null)
                return
            }

            println("📋 Found allowed image MIME types, proceeding with clipboard access")
            // Only proceed if we detected allowed image mime types
            getClipboardImage(result, allowedMimeTypes)

        } catch (e: Exception) {
            println("❌ Error in safe Android clipboard access: ${e.message}")
            e.printStackTrace()
            result.success(null) // Return null instead of error for safer handling
        }
    }
}
