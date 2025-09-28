import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    override func isContentValid() -> Bool {
        // Always return true to allow sharing
        return true
    }
    
    override func didSelectPost() {
        // Handle different types of shared content
        processSharedContent()
    }
    
    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
    
    private func processSharedContent() {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }
        
        // Process each input item
        for inputItem in inputItems {
            guard let attachments = inputItem.attachments else { continue }
            
            for attachment in attachments {
                // Handle URL (highest priority - web links, YouTube, etc.)
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                let userText = self?.contentText?.isEmpty == false ? self?.contentText : nil
                                self?.launchMainApp(content: url.absoluteString, type: "url", userText: userText)
                            } else {
                                self?.completeRequest()
                            }
                        }
                    }
                    return
                }
                
                // Handle plain text
                else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            if let text = data as? String, !text.isEmpty {
                                let userText = self?.contentText?.isEmpty == false ? self?.contentText : nil
                                self?.launchMainApp(content: text, type: "text", userText: userText)
                            } else {
                                self?.completeRequest()
                            }
                        }
                    }
                    return
                }
                
                // Handle images
                else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            self?.handleImageData(data, error: error)
                        }
                    }
                    return
                }
            }
        }
        
        // Fallback: use any text content from the compose view
        if let userText = contentText, !userText.isEmpty {
            launchMainApp(content: userText, type: "text", userText: nil)
        } else {
            completeRequest()
        }
    }
    
    private func launchMainApp(content: String, type: String, userText: String?) {
        // Build URL parameters
        var components = URLComponents()
        components.scheme = "duggy"
        components.host = "share"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "content", value: content))
        queryItems.append(URLQueryItem(name: "type", value: type))
        
        if let userText = userText {
            queryItems.append(URLQueryItem(name: "message", value: userText))
        }
        
        // Add timestamp to ensure uniqueness
        queryItems.append(URLQueryItem(name: "timestamp", value: String(Date().timeIntervalSince1970)))
        
        components.queryItems = queryItems
        
        guard let duggyURL = components.url else {
            print("❌ Failed to create Duggy URL")
            completeRequest()
            return
        }
        
        print("📤 Launching Duggy with URL: \(duggyURL)")
        
        // Launch the main app
        openURL(duggyURL) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully launched Duggy")
                } else {
                    print("❌ Failed to launch Duggy")
                }
                self?.completeRequest()
            }
        }
    }
    
    private func openURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        // Use the extension context to open the URL
        if #available(iOS 14.0, *) {
            // Modern approach for iOS 14+
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url, options: [:]) { success in
                        completion(success)
                    }
                    return
                }
                responder = responder?.next
            }
        }
        
        // Fallback for older iOS versions
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while responder != nil {
            if responder!.responds(to: selector) {
                let success = responder!.perform(selector, with: url) != nil
                completion(success)
                return
            }
            responder = responder!.next
        }
        
        completion(false)
    }
    
    private func handleImageData(_ data: Any?, error: Error?) {
        guard error == nil else {
            print("❌ Error loading image: \(error!)")
            completeRequest()
            return
        }
        
        // For now, handle all images as text messages with special marker
        let userText = contentText?.isEmpty == false ? contentText : "📸 Shared an image"
        launchMainApp(content: "📸 IMAGE_SHARED", type: "image", userText: userText)
    }
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}