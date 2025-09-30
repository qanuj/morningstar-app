import UIKit
import UniformTypeIdentifiers
import UserNotifications

final class ShareViewController: UIViewController {

    // Prevent double-completion
    private var didComplete = false

    override func loadView() {
        // Create an invisible view since we're just processing and redirecting
        view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await processSharedContent() }
    }

    // MARK: - Debug Alert Helper

    private func showDebugAlert(_ title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    // MARK: - Core

    private func completeOnce() {
        //do nothing.
        guard !didComplete else { return }
        didComplete = true
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func completeWithError(_ message: String) {
        showDebugAlert("ShareExtension Error", message: "❌ \(message)")
        completeOnce()
    }

    private func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.duggy")
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

    private func appGroupCopyTempFile(_ tempURL: URL, folder: String, filename: String) -> String? {
        guard let base = containerURL() else { return nil }
        let dir = base.appendingPathComponent(folder, isDirectory: true)
        do { try ensureDirectory(dir) } catch {
            showDebugAlert("Directory Error", message: "❌ Could not create \(folder) dir: \(error)")
            return nil
        }
        let dest = dir.appendingPathComponent(filename)
        do {
            // Overwrite if exists
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: tempURL, to: dest)
            return dest.path
        } catch {
            //showDebugAlert("Copy Error", message: "❌ Copy to app group failed: \(error)")
            return nil
        }
    }

    private func openHostApp(fallbackPayload: (content: String, type: String, userText: String?)) async {
        // Save the content to App Groups for the main app to read
        appGroupSave(content: fallbackPayload.content, type: fallbackPayload.type, userText: fallbackPayload.userText)
        await MainActor.run {
            openMainApp()
        }
    }

    private func openMainApp() {
        // Use only the working URL scheme
        let scheme = "duggy://share"

        if let url = URL(string: scheme) {
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url)
                    break
                }
                responder = responder?.next
            }
        }
    }

    // MARK: - Processing

    private func processSharedContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
            return completeWithError("No input items")
        }

        var allAttachmentTypes: [String] = []

        // Iterate attachments in priority order: URL → text → movie → file → image
        for item in items {
            guard let providers = item.attachments, !providers.isEmpty else { continue }

            // Collect all attachment types for debugging
            for provider in providers {
                let types = provider.registeredTypeIdentifiers
                allAttachmentTypes.append(contentsOf: types)
            }

            // Helper to check a provider for a UTType
            func firstProvider(conformingTo type: UTType) -> NSItemProvider? {
                providers.first { $0.hasItemConformingToTypeIdentifier(type.identifier) }
            }

            // 1) URL
            if let p = firstProvider(conformingTo: .url) {
                if let url = await loadURL(from: p) {
                    await openHostApp(fallbackPayload: (url.absoluteString, "url", "🔗 Shared a link"))
                    return completeOnce()
                }
            }

            // 2) Plain text
            if let p = firstProvider(conformingTo: .plainText) {
                if let text = await loadText(from: p) {
                    await openHostApp(fallbackPayload: (text, "text", "📝 Shared text"))
                    return completeOnce()
                }
            }

            // 3) Movie
            if let p = firstProvider(conformingTo: .movie) {
                if let temp = await loadFile(from: p, as: .movie) {
                    let name = "shared_video_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).mov"
                    if let path = appGroupCopyTempFile(temp, folder: "SharedVideos", filename: name) {
                        await openHostApp(fallbackPayload: (path, "video", "🎥 Shared a video"))
                        return completeOnce()
                    }
                }
            }

            // 4) Generic file (data / file URL)
            if let p = firstProvider(conformingTo: .data) ?? firstProvider(conformingTo: .item) {
                if let temp = await loadAnyFile(from: p) {
                    let name = "shared_file_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
                    if let path = appGroupCopyTempFile(temp, folder: "SharedFiles", filename: name) {
                        await openHostApp(fallbackPayload: (path, "file", "📄 Shared a file"))
                        return completeOnce()
                    }
                }
            }

            // 5) Image - try specific image formats first, then generic .image
            let imageTypes: [UTType] = [
                UTType(filenameExtension: "jpg") ?? .jpeg,
                UTType(filenameExtension: "jpeg") ?? .jpeg,
                .jpeg,
                .png,
                .gif,
                .webP,
                .bmp,
                .tiff,
                .image  // Generic fallback
            ]

            for imageType in imageTypes {
                if let p = firstProvider(conformingTo: imageType) {
                    if let temp = await loadFile(from: p, as: imageType) {
                        let name = "shared_image_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
                        if let path = appGroupCopyTempFile(temp, folder: "SharedImages", filename: name) {
                            await openHostApp(fallbackPayload: (path, "image", "📸 Shared an image"))
                            return completeOnce()
                        }
                    }
                }
            }

            // Also try by raw type identifier for public.jpeg
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier("public.jpeg") ||
                   provider.hasItemConformingToTypeIdentifier("public.png") ||
                   provider.hasItemConformingToTypeIdentifier("public.image") {
                    if let temp = await loadFileByIdentifier(from: provider, identifier: provider.registeredTypeIdentifiers.first { id in
                        id.contains("jpeg") || id.contains("png") || id.contains("image")
                    } ?? "public.image") {
                        let name = "shared_image_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
                        if let path = appGroupCopyTempFile(temp, folder: "SharedImages", filename: name) {
                            await openHostApp(fallbackPayload: (path, "image", "📸 Shared an image"))
                            return completeOnce()
                        }
                    }
                }
            }
        }

        // Show all found attachment types in error message
        let uniqueTypes = Array(Set(allAttachmentTypes)).sorted()
        let typesString = uniqueTypes.joined(separator: ", ")
        completeWithError("No supported attachments found. Available types: \(typesString)")
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
        // Try String directly, then plain text
        if provider.canLoadObject(ofClass: NSString.self) {
            return await withCheckedContinuation { cont in
                provider.loadObject(ofClass: NSString.self) { obj, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.showDebugAlert("Load Text Error", message: "❌ \(error)")
                        }
                    }
                    cont.resume(returning: (obj as? String as String?)?.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        return await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showDebugAlert("Load PlainText Error", message: "❌ \(error)")
                    }
                }
                if let s = item as? String {
                    cont.resume(returning: s.trimmingCharacters(in: .whitespacesAndNewlines))
                } else { cont.resume(returning: nil) }
            }
        }
    }

    private func loadFile(from provider: NSItemProvider, as type: UTType) async -> URL? {
        await withCheckedContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showDebugAlert("Load File Error", message: "❌ load file(\(type)) error: \(error)")
                    }
                }
                cont.resume(returning: url)
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
                }
                cont.resume(returning: url)
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
