import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "app.duggy/share"
  private var shareChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Register the share method channel using the plugin registry approach
    if let registrar = self.registrar(forPlugin: "ShareHandlerPlugin") {
      shareChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: registrar.messenger())
      
      shareChannel?.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        
        switch call.method {
        case "getSharedData":
          // For now, return null as iOS sharing will be handled differently
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      })
    }
    
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
}
