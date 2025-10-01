package app.duggy

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Bundle
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.*

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
                "checkSharedContent" -> {
                    // Android doesn't use App Groups like iOS, so check current intent
                    val sharedData = getSharedData(intent)
                    result.success(sharedData)
                }
                "getSharedImagesDirectory" -> {
                    val sharedDir = getSharedImagesDirectory()
                    result.success(sharedDir)
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
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                val sharedData = getSharedData(intent)
                if (sharedData != null) {
                    // Send shared data to Flutter via method channel
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARE_CHANNEL)
                        .invokeMethod("onDataReceived", sharedData)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val sharedData = getMultipleSharedData(intent)
                if (sharedData != null) {
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARE_CHANNEL)
                        .invokeMethod("onDataReceived", sharedData)
                }
            }
            Intent.ACTION_VIEW -> {
                // Handle duggy://share deep linking
                val urlData = getUrlData(intent)
                if (urlData != null) {
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARE_CHANNEL)
                        .invokeMethod("onURLReceived", urlData)
                }
            }
        }
    }

    private fun getSharedData(intent: Intent?): Map<String, Any?>? {
        if (intent?.action != Intent.ACTION_SEND) return null

        try {
            println("📤 Android getSharedData called")
            println("📤 Intent action: ${intent.action}")
            println("📤 Intent type: ${intent.type}")
            println("📤 Intent extras: ${intent.extras?.keySet()?.joinToString()}")

            val type = intent.type ?: ""
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)

            println("📤 Text: $text")
            println("📤 Subject: $subject")
            println("📤 Stream URI: $stream")
            println("📤 MIME type: $type")

            when {
                // Handle text content (including URLs)
                type == "text/plain" && text != null -> {
                    println("📤 Processing text/plain content")
                    val contentType = if (isUrl(text)) "url" else "text"
                    return mapOf(
                        "text" to text,
                        "content" to text,
                        "subject" to subject,
                        "type" to contentType,
                        "timestamp" to System.currentTimeMillis().toString()
                    )
                }

                // Handle image content
                type.startsWith("image/") && stream != null -> {
                    println("📤 Processing image content")
                    val imagePath = saveUriToFile(stream, "image")
                    return mapOf(
                        "text" to (imagePath ?: ""),
                        "content" to (imagePath ?: ""),
                        "subject" to subject,
                        "type" to "image",
                        "message" to imagePath,
                        "timestamp" to System.currentTimeMillis().toString()
                    )
                }

                // Handle video content
                type.startsWith("video/") && stream != null -> {
                    println("📤 Processing video content")
                    val videoPath = saveUriToFile(stream, "video")
                    return mapOf(
                        "text" to (videoPath ?: ""),
                        "content" to (videoPath ?: ""),
                        "subject" to subject,
                        "type" to "video",
                        "message" to videoPath,
                        "timestamp" to System.currentTimeMillis().toString()
                    )
                }

                // Handle other file types
                stream != null -> {
                    println("📤 Processing file content")
                    val filePath = saveUriToFile(stream, "file")
                    return mapOf(
                        "text" to (filePath ?: ""),
                        "content" to (filePath ?: ""),
                        "subject" to subject,
                        "type" to "file",
                        "message" to filePath,
                        "timestamp" to System.currentTimeMillis().toString()
                    )
                }

                else -> {
                    println("⚠️ Unsupported content type or missing data")
                    return null
                }
            }
        } catch (e: Exception) {
            println("❌ Error processing shared data: ${e.message}")
            e.printStackTrace()
            return null
        }
    }

    private fun getMultipleSharedData(intent: Intent?): Map<String, Any?>? {
        if (intent?.action != Intent.ACTION_SEND_MULTIPLE) return null

        try {
            println("📤 Android getMultipleSharedData called")

            val type = intent.type ?: ""
            val streams = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)

            println("📤 Multiple files count: ${streams?.size}")
            println("📤 MIME type: $type")

            if (streams.isNullOrEmpty()) {
                println("⚠️ No streams found in multiple share")
                return null
            }

            val files = mutableListOf<Map<String, Any?>>()

            streams.forEachIndexed { index, uri ->
                try {
                    println("📤 Processing file $index: $uri")
                    val filePath = saveUriToFile(uri, "file_$index")
                    if (filePath != null) {
                        val fileType = when {
                            type.startsWith("image/") -> "image"
                            type.startsWith("video/") -> "video"
                            else -> "file"
                        }

                        files.add(mapOf(
                            "path" to filePath,
                            "type" to fileType,
                            "message" to subject
                        ))
                    }
                } catch (e: Exception) {
                    println("❌ Error processing file $index: ${e.message}")
                }
            }

            if (files.isEmpty()) {
                println("⚠️ No valid files processed")
                return null
            }

            return mapOf(
                "type" to "multiple_files",
                "files" to files,
                "subject" to subject,
                "timestamp" to System.currentTimeMillis().toString()
            )

        } catch (e: Exception) {
            println("❌ Error processing multiple shared data: ${e.message}")
            e.printStackTrace()
            return null
        }
    }

    private fun getUrlData(intent: Intent?): Map<String, Any?>? {
        val uri = intent?.data
        if (uri?.scheme == "duggy" && uri.host == "share") {
            return mapOf(
                "scheme" to uri.scheme,
                "host" to uri.host,
                "path" to (uri.path ?: ""),
                "params" to mapOf(
                    "link" to uri.getQueryParameter("link"),
                    "text" to uri.getQueryParameter("text")
                ).filterValues { it != null }
            )
        }
        return null
    }

    private fun isUrl(text: String): Boolean {
        return text.startsWith("http://") || text.startsWith("https://")
    }

    private fun saveUriToFile(uri: Uri, prefix: String): String? {
        try {
            println("📤 Saving URI to file: $uri")

            val inputStream = contentResolver.openInputStream(uri) ?: return null

            // Get file extension from MIME type or URI
            val mimeType = contentResolver.getType(uri)
            val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
                ?: uri.path?.substringAfterLast('.')
                ?: when {
                    mimeType?.startsWith("image/") == true -> "jpg"
                    mimeType?.startsWith("video/") == true -> "mp4"
                    else -> "tmp"
                }

            // Create unique filename
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val filename = "${prefix}_${timestamp}.$extension"

            // Save to app's cache directory
            val file = File(cacheDir, filename)
            val outputStream = FileOutputStream(file)

            inputStream.use { input ->
                outputStream.use { output ->
                    input.copyTo(output)
                }
            }

            val filePath = file.absolutePath
            println("📤 File saved to: $filePath")
            return filePath

        } catch (e: Exception) {
            println("❌ Error saving URI to file: ${e.message}")
            e.printStackTrace()
            return null
        }
    }

    private fun getSharedImagesDirectory(): String {
        return cacheDir.absolutePath
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
