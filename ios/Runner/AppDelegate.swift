import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let SHARE_CHANNEL = "app.duggy/share"
  private let CLIPBOARD_CHANNEL = "app.duggy/clipboard"
  private var shareChannel: FlutterMethodChannel?
  private var clipboardChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    print("📱 ====== APP STARTUP ======")
    print("📱 Launch options: \(launchOptions ?? [:])")
    
    // Check if app was launched via URL
    if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL {
      print("📱 App launched with URL: \(url)")
      
      // Handle the URL after a short delay to ensure Flutter is ready
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        _ = self?.application(application, open: url, options: [:])
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Get the Flutter view controller
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Register the share method channel
    shareChannel = FlutterMethodChannel(name: SHARE_CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    shareChannel?.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      print("📱 Received Flutter method call: \(call.method)")
      print("📱 Arguments: \(call.arguments ?? "nil")")
      
      switch call.method {
      case "getSharedData":
        print("📱 Flutter requested shared data")
        // For now, return null as iOS sharing will be handled differently
        result(nil)
      case "getSharedImagesDirectory":
        print("📱 Flutter requested shared images directory")
        // Return the path to shared images directory
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.duggy") {
          let sharedImagesDir = containerURL.appendingPathComponent("SharedImages")
          print("📱 Returning shared images directory: \(sharedImagesDir.path)")
          result(sharedImagesDir.path)
        } else {
          print("📱 Could not access shared container")
          result(nil)
        }
      default:
        print("📱 Unhandled method: \(call.method)")
        result(FlutterMethodNotImplemented)
      }
    })
    
    // Register the clipboard method channel
    clipboardChannel = FlutterMethodChannel(name: CLIPBOARD_CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    clipboardChannel?.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in

      switch call.method {
      case "getClipboardImage":
        let allowedMimeTypes = (call.arguments as? [String: Any])?["allowedMimeTypes"] as? [String] ?? []
        self.getClipboardImage(result: result, allowedMimeTypes: allowedMimeTypes)
      case "getClipboardImageSafe":
        let allowedMimeTypes = (call.arguments as? [String: Any])?["allowedMimeTypes"] as? [String] ?? []
        self.getClipboardImageSafe(result: result, allowedMimeTypes: allowedMimeTypes)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    
    print("📱 ====== APP OPENED WITH URL ======")
    print("📱 URL: \(url)")
    print("📱 Scheme: \(url.scheme ?? "nil")")
    print("📱 Host: \(url.host ?? "nil")")
    print("📱 Path: \(url.path)")
    print("📱 Query: \(url.query ?? "nil")")
    print("📱 Options: \(options)")
    print("📱 ===================================")
    
    // Handle Duggy URL schemes (duggy:// and app.duggy://)
    if url.scheme == "duggy" || url.scheme == "app.duggy" {
      let result = handleDuggyURL(url)
      print("📱 Duggy URL handling result: \(result)")
      return result
    }
    
    // Handle file:// URLs for direct image sharing
    if url.scheme == "file" {
      let result = handleFileURL(url)
      print("📱 File URL handling result: \(result)")
      return result
    }
    
    print("📱 URL scheme not recognized, passing to super")
    return super.application(app, open: url, options: options)
  }
  
  private func handleDuggyURL(_ url: URL) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      print("❌ Failed to parse URL components")
      return false
    }
    
    print("📱 Processing Duggy URL - Host: \(components.host ?? "nil"), Path: \(components.path)")
    
    // Handle different paths
    switch components.host?.lowercased() {
    case "share":
      return handleShareURL(components)
    default:
      print("⚠️ Unknown URL host: \(components.host ?? "nil")")
      return handleGenericDuggyURL(components)
    }
  }
  
  private func handleShareURL(_ components: URLComponents) -> Bool {
    print("📤 ====== HANDLING SHARE URL ======")
    print("📤 URL Components: \(components)")
    print("📤 Query Items: \(components.queryItems ?? [])")
    
    var shareData: [String: Any] = [:]
    
    // Parse all query parameters
    if let queryItems = components.queryItems {
      print("📤 Processing \(queryItems.count) query items")
      for item in queryItems {
        guard let value = item.value else { 
          print("📤 Skipping query item with nil value: \(item.name)")
          continue 
        }
        
        print("📤 Processing query item: \(item.name) = \(value)")
        
        switch item.name.lowercased() {
        case "content":
          shareData["text"] = value.removingPercentEncoding ?? value
        case "type":
          shareData["type"] = value
        case "message":
          shareData["message"] = value.removingPercentEncoding ?? value
        case "timestamp":
          shareData["timestamp"] = value
        case "text": // Legacy support
          shareData["text"] = value.removingPercentEncoding ?? value
        default:
          // Store any additional parameters
          shareData[item.name] = value.removingPercentEncoding ?? value
        }
      }
    } else {
      print("📤 No query items found in URL")
    }
    
    print("📤 Parsed share data: \(shareData)")
    
    // Ensure we have at least some content
    guard shareData["text"] != nil || shareData["content"] != nil else {
      print("❌ No content found in share URL")
      return false
    }
    
    // Default type if not specified
    if shareData["type"] == nil {
      shareData["type"] = "text"
      print("📤 Defaulting type to 'text'")
    }
    
    print("📤 Final share data to send to Flutter: \(shareData)")
    
    // Check if shareChannel is available
    if shareChannel == nil {
      print("❌ Share channel is nil! Cannot send data to Flutter")
      return false
    }
    
    // Send the parsed data to Flutter
    print("📤 Invoking Flutter method 'onDataReceived'")
    shareChannel?.invokeMethod("onDataReceived", arguments: shareData)
    print("📤 ===================================")
    return true
  }
  
  private func handleFileURL(_ url: URL) -> Bool {
    print("📱 ====== HANDLING FILE URL ======")
    print("📱 File URL: \(url)")
    print("📱 File path: \(url.path)")
    
    // Check if the file exists and is an image
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: url.path) else {
      print("❌ File does not exist: \(url.path)")
      return false
    }
    
    // Check if it's an image file
    let pathExtension = url.pathExtension.lowercased()
    let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"]
    let textExtensions = ["txt", "text", "md", "rtf"]
    
    var shareData: [String: Any]
    
    if imageExtensions.contains(pathExtension) {
      print("✅ Valid image file detected: \(pathExtension)")
      
      // Create share data for the image
      shareData = [
        "text": url.path,
        "type": "image",
        "message": "📸 Shared an image",
        "timestamp": String(Date().timeIntervalSince1970)
      ]
    } else if textExtensions.contains(pathExtension) {
      print("✅ Valid text file detected: \(pathExtension)")
      
      // Read text file content
      do {
        let textContent = try String(contentsOf: url, encoding: .utf8)
        print("📱 Text file content: \(textContent.prefix(100))...")
        
        shareData = [
          "text": textContent,
          "type": "text",
          "message": textContent,
          "timestamp": String(Date().timeIntervalSince1970)
        ]
      } catch {
        print("❌ Failed to read text file: \(error)")
        return false
      }
    } else {
      print("❌ File is not an image or text file: \(pathExtension)")
      return false
    }
    
    print("📤 Sending file data to Flutter: \(shareData)")
    
    // Check if shareChannel is available
    if shareChannel == nil {
      print("❌ Share channel is nil! Cannot send data to Flutter")
      return false
    }
    
    // Send the file data to Flutter
    print("📤 Invoking Flutter method 'onDataReceived' for file")
    shareChannel?.invokeMethod("onDataReceived", arguments: shareData)
    print("📤 ===================================")
    return true
  }
  
  private func handleGenericDuggyURL(_ components: URLComponents) -> Bool {
    // Handle any other duggy:// URLs that might be called by external apps
    var urlData: [String: Any] = [
      "scheme": components.scheme ?? "",
      "host": components.host ?? "",
      "path": components.path
    ]
    
    // Include query parameters if any
    if let queryItems = components.queryItems {
      var params: [String: String] = [:]
      for item in queryItems {
        if let value = item.value {
          params[item.name] = value.removingPercentEncoding ?? value
        }
      }
      urlData["params"] = params
    }
    
    print("📤 Sending generic URL data to Flutter: \(urlData)")
    
    // Send to Flutter for custom handling
    shareChannel?.invokeMethod("onURLReceived", arguments: urlData)
    return true
  }
  
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    
    // Handle universal links and web URLs
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      
      shareChannel?.invokeMethod("onDataReceived", arguments: [
        "text": url.absoluteString,
        "type": "url"
      ])
      return true
    }
    
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
  
  private func getClipboardImage(result: @escaping FlutterResult, allowedMimeTypes: [String]) {
    print("📋 iOS getClipboardImage method called with MIME types: \(allowedMimeTypes)")
    let pasteboard = UIPasteboard.general

    // Check what types are available in the clipboard
    print("📋 Available types in clipboard: \(pasteboard.types)")
    print("📋 Has images: \(pasteboard.hasImages)")
    print("📋 Has strings: \(pasteboard.hasStrings)")

    // Create a mapping of MIME types to iOS UTI types
    let mimeToUTI = [
      "image/png": "public.png",
      "image/jpeg": "public.jpeg",
      "image/gif": "com.compuserve.gif",
      "image/webp": "org.webmproject.webp",
      "image/bmp": "com.microsoft.bmp"
    ]

    // Check if clipboard contains any allowed image types
    var foundValidType = false
    if !allowedMimeTypes.isEmpty {
      for mimeType in allowedMimeTypes {
        if let utiType = mimeToUTI[mimeType] {
          if pasteboard.contains(pasteboardTypes: [utiType]) {
            print("📋 Found allowed MIME type: \(mimeType) (\(utiType))")
            foundValidType = true
            break
          }
        }
      }

      if !foundValidType {
        print("📋 No allowed MIME types found in clipboard")
        result(nil)
        return
      }
    }

    // Check if there's an image in the clipboard
    if pasteboard.hasImages {
      if let image = pasteboard.image {
        print("📋 Found UIImage in clipboard: \(image.size)")
        // Convert UIImage to PNG data (standardize format)
        if let imageData = image.pngData() {
          print("📋 Successfully converted to PNG data, size: \(imageData.count) bytes")
          result(FlutterStandardTypedData(bytes: imageData))
          return
        } else {
          print("❌ Failed to convert UIImage to PNG data")
        }
      } else {
        print("❌ pasteboard.hasImages is true but pasteboard.image is nil")
      }
    }

    print("📋 No valid image found in iOS clipboard")
    result(nil)
  }

  private func getClipboardImageSafe(result: @escaping FlutterResult, allowedMimeTypes: [String]) {
    print("📋 iOS getClipboardImageSafe method called with MIME types: \(allowedMimeTypes)")
    let pasteboard = UIPasteboard.general

    // First check if we can access the pasteboard without causing permission prompt
    guard pasteboard.numberOfItems > 0 else {
      print("📋 Clipboard is empty")
      result(nil)
      return
    }

    // Create a mapping of MIME types to iOS UTI types
    let mimeToUTI = [
      "image/png": "public.png",
      "image/jpeg": "public.jpeg",
      "image/gif": "com.compuserve.gif",
      "image/webp": "org.webmproject.webp",
      "image/bmp": "com.microsoft.bmp"
    ]

    // Check if there are any allowed image types available without accessing the content
    let availableTypes = pasteboard.types
    var allowedUTITypes = ["public.image"] // Generic image fallback

    // Add specific UTI types based on allowed MIME types
    if !allowedMimeTypes.isEmpty {
      for mimeType in allowedMimeTypes {
        if let utiType = mimeToUTI[mimeType] {
          allowedUTITypes.append(utiType)
        }
      }
    } else {
      // Default allowed types if none specified
      allowedUTITypes.append(contentsOf: ["public.png", "public.jpeg", "com.compuserve.gif"])
    }

    let hasAllowedImageType = availableTypes.contains { type in
      allowedUTITypes.contains(type)
    }

    print("📋 Available types: \(availableTypes)")
    print("📋 Allowed UTI types: \(allowedUTITypes)")
    print("📋 Has allowed image type: \(hasAllowedImageType)")

    guard hasAllowedImageType else {
      print("📋 No allowed image types found in clipboard")
      result(nil)
      return
    }

    // Only access the image if we know it's there and allowed
    if pasteboard.hasImages {
      if let image = pasteboard.image {
        print("📋 Found UIImage in clipboard: \(image.size)")
        // Convert UIImage to PNG data (standardize format)
        if let imageData = image.pngData() {
          print("📋 Successfully converted to PNG data, size: \(imageData.count) bytes")
          result(FlutterStandardTypedData(bytes: imageData))
          return
        } else {
          print("❌ Failed to convert UIImage to PNG data")
        }
      }
    }

    print("📋 No accessible allowed image found in iOS clipboard")
    result(nil)
  }
}
