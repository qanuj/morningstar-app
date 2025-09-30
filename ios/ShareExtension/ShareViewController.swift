import UIKit
import UniformTypeIdentifiers
import UserNotifications

final class ShareViewController: UIViewController {

    // Prevent double-completion
    private var didComplete = false

    // Debug log for tracking all steps
    private var debugLog: [String] = []

    override func loadView() {
        // Create an invisible view since we're just processing and redirecting
        view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logStep("ShareExtension viewDidLoad - Starting content processing")
        Task { await processSharedContent() }
    }

    // MARK: - Debug Logging

    private func logStep(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"
        debugLog.append(logEntry)
        print("LOG: \(logEntry)")
    }

    private func showDebugAlert(_ title: String, message: String) {
        logStep("\(title): \(message)")
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private func showFinalLog() {
        let fullLog = debugLog.joined(separator: "\n")
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "ShareExtension Debug Log", message: fullLog, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
                UIPasteboard.general.string = fullLog
            })
            alert.addAction(UIAlertAction(title: "Close", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    // MARK: - Core

    private func completeOnce() {
        guard !didComplete else { return }
        didComplete = true
        logStep("ShareExtension completing...")

        // Show final log before closing
        showFinalLog()

        // Complete after a delay to allow user to see the log
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func completeWithError(_ message: String) {
        logStep("ERROR: \(message)")
        showFinalLog()

        // Complete after a delay to allow user to see the log
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func containerURL() -> URL? {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.duggy")
        if let url = containerURL {
            logStep("App Group container found: \(url.path)")
        } else {
            logStep("App Group container NOT found for 'group.app.duggy'")
        }
        return containerURL
    }

    private func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    private func appGroupSave(content: String, type: String, userText: String?) {
        guard let base = containerURL() else { return }

        let dir = base.appendingPathComponent("SharedData", isDirectory: true)
        do { try ensureDirectory(dir) } catch {
            showDebugAlert("Directory Error", message: "❌ Could not create SharedData dir: \(error)")
            return
        }

        let payload: [String: Any] = [
            "content": content,
            "type": type,
            "message": userText ?? "",
            "timestamp": Date().timeIntervalSince1970
        ]

        let file = dir.appendingPathComponent("shared_content_\(Int(Date().timeIntervalSince1970)).json")
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            try data.write(to: file, options: .atomic)
        } catch {
            showDebugAlert("Save Error", message: "❌ Failed to persist payload: \(error)")
        }
    }

    private func appGroupSaveMultipleFiles(processedFiles: [(path: String, type: String, message: String)]) {
        guard let base = containerURL() else { return }

        let dir = base.appendingPathComponent("SharedData", isDirectory: true)
        do { try ensureDirectory(dir) } catch {
            showDebugAlert("Directory Error", message: "❌ Could not create SharedData dir: \(error)")
            return
        }

        // Create array of file data
        let filesData = processedFiles.map { file in
            return [
                "content": file.path,
                "type": file.type,
                "message": file.message
            ]
        }

        let payload: [String: Any] = [
            "files": filesData,
            "type": "multiple_files",
            "timestamp": Date().timeIntervalSince1970
        ]

        let file = dir.appendingPathComponent("shared_content_\(Int(Date().timeIntervalSince1970)).json")
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            try data.write(to: file, options: .atomic)
            logStep("Successfully saved multiple files data to App Groups")
        } catch {
            showDebugAlert("Save Error", message: "❌ Failed to persist multiple files payload: \(error)")
        }
    }

    private func appGroupCopyTempFile(_ tempURL: URL, folder: String, filename: String) -> String? {
        logStep("appGroupCopyTempFile called for \(filename) in \(folder)")

        guard let base = containerURL() else {
            logStep("Failed to get App Group container URL")
            return nil
        }
        logStep("App Group container URL: \(base.path)")

        let dir = base.appendingPathComponent(folder, isDirectory: true)
        logStep("Target directory: \(dir.path)")

        do {
            try ensureDirectory(dir)
            logStep("Successfully ensured directory exists")
        } catch {
            logStep("Failed to create directory: \(error)")
            showDebugAlert("Directory Error", message: "❌ Could not create \(folder) dir: \(error)")
            return nil
        }

        let dest = dir.appendingPathComponent(filename)
        logStep("Destination file: \(dest.path)")
        logStep("Source file: \(tempURL.path)")

        // Check if source file exists and is readable
        if FileManager.default.fileExists(atPath: tempURL.path) {
            logStep("Source file exists")
        } else {
            logStep("Source file does NOT exist")
            return nil
        }

        do {
            // Overwrite if exists
            if FileManager.default.fileExists(atPath: dest.path) {
                logStep("Destination file exists, removing...")
                try FileManager.default.removeItem(at: dest)
                logStep("Successfully removed existing destination file")
            }

            logStep("Attempting to copy file...")
            try FileManager.default.copyItem(at: tempURL, to: dest)
            logStep("Successfully copied file to app group")
            return dest.path
        } catch {
            logStep("Copy failed with error: \(error)")
            logStep("Error details: \(error.localizedDescription)")
            return nil
        }
    }

    private func openHostApp(fallbackPayload: (content: String, type: String, userText: String?)) async {
        logStep("openHostApp called with type: \(fallbackPayload.type)")

        // Check if this is a URL that should use the URL scheme - ANY URL
        if fallbackPayload.type == "url" {
            let urlString = fallbackPayload.content
            logStep("Detected URL share: \(urlString)")
            logStep("Using URL scheme for ANY URL")
            await MainActor.run {
                openMainApp(withURL: urlString)
            }
            return
        }

        // Check if this is plain text that should use the URL scheme - ANY TEXT
        if fallbackPayload.type == "text" {
            let textString = fallbackPayload.content
            logStep("Detected text share: \(textString)")
            logStep("Using URL scheme for ANY text")
            await MainActor.run {
                openMainApp(withText: textString)
            }
            return
        }

        // Save the content to App Groups for the main app to read
        appGroupSave(content: fallbackPayload.content, type: fallbackPayload.type, userText: fallbackPayload.userText)
        await MainActor.run {
            openMainApp()
        }
    }

    private func openHostAppWithMultipleFiles(processedFiles: [(path: String, type: String, message: String)]) async {
        logStep("openHostAppWithMultipleFiles called with \(processedFiles.count) files")

        // Save data for multiple files to App Groups
        appGroupSaveMultipleFiles(processedFiles: processedFiles)

        await MainActor.run {
            openMainApp()
        }
    }

    private func openMainApp() {
        logStep("openMainApp called - attempting to launch main app")
        // Use only the working URL scheme
        let scheme = "duggy://share"

        if let url = URL(string: scheme) {
            logStep("Valid URL created: \(scheme)")
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    logStep("Found UIApplication, calling open(url)")
                    application.open(url)
                    break
                }
                responder = responder?.next
            }
            logStep("App launch attempt completed")
        } else {
            logStep("Failed to create URL from scheme: \(scheme)")
        }
    }

    private func openMainApp(withURL urlString: String) {
        logStep("openMainApp called with URL - attempting to launch main app with URL: \(urlString)")

        // URL encode the link parameter
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            logStep("Failed to URL encode the shared URL")
            // Fallback to regular launch
            openMainApp()
            return
        }

        // Use the URL scheme with link parameter
        let scheme = "duggy://share?link=\(encodedURL)"

        if let url = URL(string: scheme) {
            logStep("Valid URL created: \(scheme)")
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    logStep("Found UIApplication, calling open(url) with link parameter")
                    application.open(url)
                    break
                }
                responder = responder?.next
            }
            logStep("App launch with URL attempt completed")
        } else {
            logStep("Failed to create URL from scheme: \(scheme)")
            // Fallback to regular launch
            openMainApp()
        }
    }

    private func openMainApp(withText textString: String) {
        logStep("openMainApp called with text - attempting to launch main app with text: \(textString)")

        // URL encode the text parameter
        guard let encodedText = textString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            logStep("Failed to URL encode the shared text")
            // Fallback to regular launch
            openMainApp()
            return
        }

        // Use the URL scheme with text parameter
        let scheme = "duggy://share?text=\(encodedText)"

        if let url = URL(string: scheme) {
            logStep("Valid URL created: \(scheme)")
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    logStep("Found UIApplication, calling open(url) with text parameter")
                    application.open(url)
                    break
                }
                responder = responder?.next
            }
            logStep("App launch with text attempt completed")
        } else {
            logStep("Failed to create URL from scheme: \(scheme)")
            // Fallback to regular launch
            openMainApp()
        }
    }

    // MARK: - Processing

    private func processSharedContent() async {
        logStep("Starting processSharedContent")

        guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
            return completeWithError("No input items")
        }

        logStep("Found \(items.count) input item(s)")
        var allAttachmentTypes: [String] = []
        var processedFiles: [(path: String, type: String, message: String)] = []

        // Iterate through all items to collect all files first
        for (itemIndex, item) in items.enumerated() {
            logStep("Processing item \(itemIndex + 1)")

            guard let providers = item.attachments, !providers.isEmpty else {
                logStep("Item \(itemIndex + 1) has no attachments")
                continue
            }

            logStep("Item \(itemIndex + 1) has \(providers.count) provider(s)")

            // Collect all attachment types for debugging
            for (providerIndex, provider) in providers.enumerated() {
                let types = provider.registeredTypeIdentifiers
                logStep("Provider \(providerIndex + 1) types: \(types.joined(separator: ", "))")
                allAttachmentTypes.append(contentsOf: types)
            }

            // Process each provider to collect all files
            for (providerIndex, provider) in providers.enumerated() {
                logStep("Processing provider \(providerIndex + 1) of item \(itemIndex + 1)")

                // Try different content types for this provider
                var processed = false

                // 1) URL
                if !processed && provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    logStep("Provider has URL, attempting to load...")
                    if let url = await loadURL(from: provider) {
                        logStep("Successfully loaded URL: \(url.absoluteString)")
                        processedFiles.append((url.absoluteString, "url", "🔗 Shared a link"))
                        processed = true
                    }
                }

                // 2) Plain text
                if !processed && provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    logStep("Provider has plain text, attempting to load...")
                    if let text = await loadText(from: provider) {
                        logStep("Successfully loaded text: \(text.prefix(50))...")
                        processedFiles.append((text, "text", "📝 Shared text"))
                        processed = true
                    }
                }

                // 3) Movie
                if !processed && provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    logStep("Provider has movie, attempting to load...")
                    if let copiedFile = await loadFile(from: provider, as: .movie) {
                        logStep("Successfully loaded and copied movie file: \(copiedFile.path)")
                        processedFiles.append((copiedFile.path, "video", "🎥 Shared a video"))
                        processed = true
                    }
                }

                // 4) Images - try multiple image types
                if !processed {
                    let imageTypes: [UTType] = [.jpeg, .png, .gif, .webP, .bmp, .tiff, .image]
                    for imageType in imageTypes {
                        if provider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                            logStep("Provider has \(imageType.identifier), attempting to load...")
                            if let copiedFile = await loadFile(from: provider, as: imageType) {
                                logStep("Successfully loaded and copied image file: \(copiedFile.path)")
                                processedFiles.append((copiedFile.path, "image", "📸 Shared an image"))
                                processed = true
                                break
                            }
                        }
                    }
                }

                // 5) Raw type identifiers for images
                if !processed {
                    for typeId in provider.registeredTypeIdentifiers {
                        if typeId.contains("jpeg") || typeId.contains("png") || typeId.contains("image") {
                            logStep("Provider has raw image type \(typeId), attempting to load...")
                            if let copiedFile = await loadFileByIdentifier(from: provider, identifier: typeId) {
                                logStep("Successfully loaded and copied raw image file: \(copiedFile.path)")
                                processedFiles.append((copiedFile.path, "image", "📸 Shared an image"))
                                processed = true
                                break
                            }
                        }
                    }
                }

                // 6) Generic file
                if !processed && (provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) ||
                                  provider.hasItemConformingToTypeIdentifier(UTType.item.identifier)) {
                    logStep("Provider has generic data, attempting to load...")
                    if let copiedFile = await loadAnyFile(from: provider) {
                        logStep("Successfully loaded and copied generic file: \(copiedFile.path)")
                        processedFiles.append((copiedFile.path, "file", "📄 Shared a file"))
                        processed = true
                    }
                }

                if !processed {
                    logStep("Could not process provider \(providerIndex + 1) with types: \(provider.registeredTypeIdentifiers.joined(separator: ", "))")
                }
            }
        }

        // Process results
        if processedFiles.isEmpty {
            let uniqueTypes = Array(Set(allAttachmentTypes)).sorted()
            let typesString = uniqueTypes.joined(separator: ", ")
            completeWithError("No supported attachments found. Available types: \(typesString)")
        } else {
            logStep("Successfully processed \(processedFiles.count) file(s)")

            // Check if we have ANY URL or TEXT - if so, use the URL scheme handling path
            let urlFile = processedFiles.first { $0.type == "url" }
            let textFile = processedFiles.first { $0.type == "text" }

            if let urlFile = urlFile {
                logStep("Found URL in processed files: \(urlFile.path)")
                await openHostApp(fallbackPayload: (content: urlFile.path, type: urlFile.type, userText: urlFile.message))
            } else if let textFile = textFile {
                logStep("Found text in processed files: \(textFile.path)")
                await openHostApp(fallbackPayload: (content: textFile.path, type: textFile.type, userText: textFile.message))
            } else {
                // Process all files and pass them to the Flutter app
                logStep("No URLs or text found, processing as multiple files")
                await openHostAppWithMultipleFiles(processedFiles: processedFiles)
            }
            completeOnce()
        }
    }

    // MARK: - NSItemProvider loaders (async)

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showDebugAlert("Load URL Error", message: "❌ \(error)")
                    }
                }
                cont.resume(returning: item as? URL)
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        // Try multiple approaches to extract text content

        // First try: Load as plain text using UTType
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let result = await withCheckedContinuation { cont in
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    if let error = error {
                        self.logStep("PlainText load error: \(error)")
                        cont.resume(returning: nil)
                        return
                    }

                    if let string = item as? String {
                        cont.resume(returning: string.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                        cont.resume(returning: string.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else if let url = item as? URL {
                        // Sometimes URLs come as plain text
                        cont.resume(returning: url.absoluteString)
                    } else {
                        self.logStep("PlainText item is not a string: \(type(of: item))")
                        cont.resume(returning: nil)
                    }
                }
            }
            if let result = result, !result.isEmpty {
                logStep("Successfully loaded text via UTType.plainText: \(result.prefix(50))...")
                return result
            }
        }

        // Second try: Load as NSString object (only if we can safely do so)
        if provider.canLoadObject(ofClass: NSString.self) {
            let result = await withCheckedContinuation { cont in
                provider.loadObject(ofClass: NSString.self) { obj, error in
                    if let error = error {
                        self.logStep("NSString load error (expected): \(error)")
                        cont.resume(returning: nil)
                        return
                    }

                    if let string = obj as? String {
                        cont.resume(returning: string.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        cont.resume(returning: nil)
                    }
                }
            }
            if let result = result, !result.isEmpty {
                logStep("Successfully loaded text via NSString: \(result.prefix(50))...")
                return result
            }
        }

        // Third try: Try other text-related type identifiers
        let textTypes = ["public.text", "public.utf8-plain-text", "public.utf16-plain-text"]
        for textType in textTypes {
            if provider.hasItemConformingToTypeIdentifier(textType) {
                let result = await withCheckedContinuation { cont in
                    provider.loadItem(forTypeIdentifier: textType, options: nil) { item, error in
                        if let error = error {
                            self.logStep("Text type \(textType) load error: \(error)")
                            cont.resume(returning: nil)
                            return
                        }

                        if let string = item as? String {
                            cont.resume(returning: string.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                            cont.resume(returning: string.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            cont.resume(returning: nil)
                        }
                    }
                }
                if let result = result, !result.isEmpty {
                    logStep("Successfully loaded text via \(textType): \(result.prefix(50))...")
                    return result
                }
            }
        }

        logStep("Failed to load text from provider with types: \(provider.registeredTypeIdentifiers)")
        return nil
    }

    private func loadFile(from provider: NSItemProvider, as type: UTType) async -> URL? {
        await withCheckedContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showDebugAlert("Load File Error", message: "❌ load file(\(type)) error: \(error)")
                    }
                    cont.resume(returning: nil)
                    return
                }

                guard let tempURL = url else {
                    cont.resume(returning: nil)
                    return
                }

                // Copy immediately while temp file still exists
                self.logStep("Temp file received: \(tempURL.path)")

                // Determine appropriate folder and filename based on type
                let (folder, filename): (String, String)
                if type == .movie || type.identifier.contains("movie") || type.identifier.contains("video") {
                    folder = "SharedVideos"
                    filename = "shared_video_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).mov"
                } else if type == .image || type.identifier.contains("image") || type.identifier.contains("jpeg") || type.identifier.contains("png") {
                    folder = "SharedImages"
                    filename = "shared_image_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
                } else {
                    folder = "SharedFiles"
                    filename = "shared_file_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
                }

                if let copiedPath = self.appGroupCopyTempFile(tempURL, folder: folder, filename: filename) {
                    // Return the copied file URL instead of temp URL
                    cont.resume(returning: URL(fileURLWithPath: copiedPath))
                } else {
                    self.logStep("Failed to copy temp file immediately")
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private func loadFileByIdentifier(from provider: NSItemProvider, identifier: String) async -> URL? {
        await withCheckedContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showDebugAlert("Load File by ID Error", message: "❌ load file(\(identifier)) error: \(error)")
                    }
                    cont.resume(returning: nil)
                    return
                }

                guard let tempURL = url else {
                    cont.resume(returning: nil)
                    return
                }

                // Copy immediately while temp file still exists
                self.logStep("Temp file received by identifier: \(tempURL.path)")

                // Determine appropriate folder and filename based on identifier
                let (folder, filename): (String, String)
                if identifier.contains("movie") || identifier.contains("video") || identifier.contains("mpeg") || identifier.contains("quicktime") {
                    folder = "SharedVideos"
                    filename = "shared_video_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).mov"
                } else if identifier.contains("image") || identifier.contains("jpeg") || identifier.contains("png") {
                    folder = "SharedImages"
                    filename = "shared_image_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
                } else {
                    folder = "SharedFiles"
                    filename = "shared_file_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
                }

                if let copiedPath = self.appGroupCopyTempFile(tempURL, folder: folder, filename: filename) {
                    // Return the copied file URL instead of temp URL
                    cont.resume(returning: URL(fileURLWithPath: copiedPath))
                } else {
                    self.logStep("Failed to copy temp file immediately by identifier")
                    cont.resume(returning: nil)
                }
            }
        }
    }

    // Tries data/movie/image/fileURL in order for generic files
    private func loadAnyFile(from provider: NSItemProvider) async -> URL? {
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            if let u = await loadFile(from: provider, as: .data) { return u }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            if let u = await loadFile(from: provider, as: .movie) { return u }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let u = await loadFile(from: provider, as: .image) { return u }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let u = await loadFile(from: provider, as: .fileURL) { return u }
        }
        return nil
    }

    // MARK: - Notification Fallback

    private func sendNotificationFallback(type: String, userText: String?) async {
        showDebugAlert("Notification", message: "📤 Sending local notification as fallback...")

        let center = UNUserNotificationCenter.current()

        // Request permission
        let permissionGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showDebugAlert("Notification Permission Error", message: "❌ \(error)")
                    }
                }
                cont.resume(returning: granted)
            }
        }

        guard permissionGranted else {
            showDebugAlert("Permission Denied", message: "⚠️ Notification permission not granted")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Content Shared to Duggy"

        switch type.lowercased() {
        case "video":
            content.body = "Tap to open Duggy and share your video with clubs"
        case "image":
            content.body = "Tap to open Duggy and share your image with clubs"
        case "url":
            content.body = "Tap to open Duggy and share your link with clubs"
        default:
            content.body = "Tap to open Duggy and share with clubs"
        }

        content.sound = .default
        content.userInfo = ["action": "open_shared_content"]

        // Add action to open the app
        let openAction = UNNotificationAction(identifier: "OPEN_APP", title: "Open Duggy", options: [.foreground])
        let category = UNNotificationCategory(identifier: "DUGGY_SHARE", actions: [openAction], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
        content.categoryIdentifier = "DUGGY_SHARE"

        let request = UNNotificationRequest(identifier: "duggy_share", content: content, trigger: nil)

        do {
            try await center.add(request)
            showDebugAlert("Notification Success", message: "✅ Local notification sent successfully")
        } catch {
            showDebugAlert("Notification Error", message: "❌ Failed to send notification: \(error)")
        }
    }
}
