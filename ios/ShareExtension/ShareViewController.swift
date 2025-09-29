import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📤 ====== SHARE EXTENSION LOADED ======")
        print("📤 Share extension view did load")
        print("📤 ===================================")
    }
    
    override func isContentValid() -> Bool {
        print("📤 Share extension isContentValid called")
        // Always return true to allow sharing
        return true
    }
    
    override func didSelectPost() {
        print("📤 ====== SHARE EXTENSION TRIGGERED ======")
        print("📤 Content text: \(contentText ?? "nil")")
        print("📤 Processing shared content...")
        
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
                    print("📤 Processing plain text attachment")
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            print("📤 Plain text loaded: \(data ?? "nil"), error: \(error?.localizedDescription ?? "none")")
                            if let text = data as? String, !text.isEmpty {
                                let userText = self?.contentText?.isEmpty == false ? self?.contentText : nil
                                print("📤 Sharing text: \(text), user text: \(userText ?? "nil")")
                                self?.launchMainApp(content: text, type: "text", userText: userText)
                            } else {
                                print("📤 No valid text found, completing request")
                                self?.completeRequest()
                            }
                        }
                    }
                    return
                }
                
                // Handle videos
                else if attachment.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            self?.handleVideoData(data, error: error)
                        }
                    }
                    return
                }

                // Handle files (from Files app)
                else if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            if let fileURL = data as? URL {
                                let userText = self?.contentText?.isEmpty == false ? self?.contentText : nil
                                self?.launchMainApp(content: fileURL.path, type: "file", userText: userText)
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
        print("📤 ====== LAUNCHING MAIN APP ======")
        print("📤 Content: \(content)")
        print("📤 Type: \(type)")
        print("📤 User text: \(userText ?? "nil")")
        
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
        
        print("📤 Query items: \(queryItems)")
        
        components.queryItems = queryItems
        
        guard let duggyURL = components.url else {
            print("❌ Failed to create Duggy URL from components: \(components)")
            completeRequest()
            return
        }
        
        print("📤 Created Duggy URL: \(duggyURL)")
        print("📤 URL absolute string: \(duggyURL.absoluteString)")
        print("📤 Attempting to launch main app...")
        
        // Launch the main app
        openURL(duggyURL) { [weak self] success in
            DispatchQueue.main.async {
                print("📤 URL launch completion called")
                if success {
                    print("✅ Successfully launched Duggy")
                } else {
                    print("❌ Failed to launch Duggy - URL scheme may not be registered")
                }
                print("📤 ===================================")
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

        // Save image to shared container and get file path
        if let imagePath = saveImageToSharedContainer(data) {
            let userText = contentText?.isEmpty == false ? contentText : "📸 Shared an image"
            launchMainApp(content: imagePath, type: "image", userText: userText)
        } else {
            print("❌ Failed to save image to shared container")
            // Fallback to text message
            let userText = contentText?.isEmpty == false ? contentText : "📸 Shared an image"
            launchMainApp(content: "📸 IMAGE_SHARED", type: "image", userText: userText)
        }
    }

    private func handleVideoData(_ data: Any?, error: Error?) {
        guard error == nil else {
            print("❌ Error loading video: \(error!)")
            completeRequest()
            return
        }

        // Save video to shared container and get file path
        if let videoPath = saveVideoToSharedContainer(data) {
            let userText = contentText?.isEmpty == false ? contentText : "🎥 Shared a video"
            launchMainApp(content: videoPath, type: "video", userText: userText)
        } else {
            print("❌ Failed to save video to shared container")
            // Fallback to text message
            let userText = contentText?.isEmpty == false ? contentText : "🎥 Shared a video"
            launchMainApp(content: "🎥 VIDEO_SHARED", type: "video", userText: userText)
        }
    }
    
    private func saveImageToSharedContainer(_ data: Any?) -> String? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.duggy") else {
            print("❌ Could not access shared container")
            return nil
        }
        
        let sharedImagesDir = containerURL.appendingPathComponent("SharedImages")
        
        // Create directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: sharedImagesDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create shared images directory: \(error)")
            return nil
        }
        
        // Generate unique filename
        let filename = "shared_image_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
        let fileURL = sharedImagesDir.appendingPathComponent(filename)
        
        // Convert data to image and save
        var imageData: Data?
        
        if let url = data as? URL {
            // If data is a URL, load the image data
            do {
                imageData = try Data(contentsOf: url)
            } catch {
                print("❌ Failed to load image data from URL: \(error)")
                return nil
            }
        } else if let image = data as? UIImage {
            // If data is a UIImage, convert to JPEG
            imageData = image.jpegData(compressionQuality: 0.8)
        } else if let data = data as? Data {
            // If data is already Data, use it directly
            imageData = data
        } else {
            print("❌ Unsupported image data type: \(type(of: data))")
            return nil
        }
        
        guard let finalImageData = imageData else {
            print("❌ Could not get image data")
            return nil
        }
        
        // Save to file
        do {
            try finalImageData.write(to: fileURL)
            print("✅ Saved shared image to: \(fileURL.path)")
            return fileURL.path
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }
    }
    
    private func saveVideoToSharedContainer(_ data: Any?) -> String? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.duggy") else {
            print("❌ Could not access shared container")
            return nil
        }

        let sharedVideosDir = containerURL.appendingPathComponent("SharedVideos")

        // Create directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: sharedVideosDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create shared videos directory: \(error)")
            return nil
        }

        // Generate unique filename
        let filename = "shared_video_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).mov"
        let fileURL = sharedVideosDir.appendingPathComponent(filename)

        // Convert data to video and save
        var videoData: Data?

        if let url = data as? URL {
            // If data is a URL, load the video data
            do {
                videoData = try Data(contentsOf: url)
            } catch {
                print("❌ Failed to load video data from URL: \(error)")
                return nil
            }
        } else if let data = data as? Data {
            // If data is already Data, use it directly
            videoData = data
        } else {
            print("❌ Unsupported video data type: \(type(of: data))")
            return nil
        }

        guard let finalVideoData = videoData else {
            print("❌ Could not get video data")
            return nil
        }

        // Save to file
        do {
            try finalVideoData.write(to: fileURL)
            print("✅ Saved shared video to: \(fileURL.path)")
            return fileURL.path
        } catch {
            print("❌ Failed to save video: \(error)")
            return nil
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}