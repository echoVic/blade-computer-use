import AppKit
import Foundation
import ScreenCaptureKit

enum WindowScreenshot {
    static func capture(processID: pid_t, title: String) async throws -> String {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        guard let window = content.windows.first(where: { candidate in
            guard candidate.owningApplication?.processID == processID else { return false }
            return title.isEmpty || candidate.title == title
        }) ?? content.windows.first(where: { $0.owningApplication?.processID == processID }) else {
            throw HelperError(code: "window_not_found", message: "No capturable window was found.")
        }

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(window.frame.width * 2))
        configuration.height = max(1, Int(window.frame.height * 2))
        configuration.showsCursor = true
        configuration.captureResolution = .best

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw HelperError(code: "native_helper_error", message: "Could not encode screenshot as PNG.")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("blade-computer-use", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let file = directory.appendingPathComponent("\(UUID().uuidString).png")
        try data.write(to: file, options: .atomic)
        return file.path
    }
}
