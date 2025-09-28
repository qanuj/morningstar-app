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
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Get the Flutter view controller
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Register the share method channel
    shareChannel = FlutterMethodChannel(name: SHARE_CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    shareChannel?.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      switch call.method {
      case "getSharedData":
        // For now, return null as iOS sharing will be handled differently
        result(nil)
      case "getSharedImagesDirectory":
        // Return the path to shared images directory
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.duggy") {
          let sharedImagesDir = containerURL.appendingPathComponent("SharedImages")
          result(sharedImagesDir.path)
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    // Register the clipboard method channel
    clipboardChannel = FlutterMethodChannel(name: CLIPBOARD_CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    clipboardChannel?.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      switch call.method {
      case "getClipboardImage":
        self.getClipboardImage(result: result)
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
    
    print("📱 App opened with URL: \(url)")
    
    // Handle Duggy URL schemes (duggy:// and app.duggy://)
    if url.scheme == "duggy" || url.scheme == "app.duggy" {
      return handleDuggyURL(url)
    }
    
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
    var shareData: [String: Any] = [:]
    
    // Parse all query parameters
    if let queryItems = components.queryItems {
      for item in queryItems {
        guard let value = item.value else { continue }
        
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
    }
    
    // Ensure we have at least some content
    guard shareData["text"] != nil || shareData["content"] != nil else {
      print("❌ No content found in share URL")
      return false
    }
    
    // Default type if not specified
    if shareData["type"] == nil {
      shareData["type"] = "text"
    }
    
    print("📤 Sending share data to Flutter: \(shareData)")
    
    // Send the parsed data to Flutter
    shareChannel?.invokeMethod("onDataReceived", arguments: shareData)
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
  
  private func getClipboardImage(result: @escaping FlutterResult) {
    print("📋 iOS getClipboardImage method called")
    let pasteboard = UIPasteboard.general
    
    // Check what types are available in the clipboard
    print("📋 Available types in clipboard: \(pasteboard.types)")
    print("📋 Has images: \(pasteboard.hasImages)")
    print("📋 Has strings: \(pasteboard.hasStrings)")
    
    // Check if there's an image in the clipboard
    if pasteboard.hasImages {
      if let image = pasteboard.image {
        print("📋 Found UIImage in clipboard: \(image.size)")
        // Convert UIImage to PNG data
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
    
    print("📋 No image found in iOS clipboard")
    result(nil)
  }
}
