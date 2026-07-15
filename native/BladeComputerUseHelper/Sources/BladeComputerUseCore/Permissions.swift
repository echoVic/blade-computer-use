import ApplicationServices
import CoreGraphics
import Foundation

public protocol PermissionChecking {
    func accessibilityTrusted(prompt: Bool) -> Bool
    func screenRecordingTrusted(prompt: Bool) -> Bool
}

public struct SystemPermissionChecker: PermissionChecking {
    public init() {}

    public func accessibilityTrusted(prompt: Bool) -> Bool {
        guard prompt else { return AXIsProcessTrusted() }
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func screenRecordingTrusted(prompt: Bool) -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return prompt && CGRequestScreenCaptureAccess()
    }
}

public struct PermissionStatus: Equatable, Sendable {
    public let accessibilityTrusted: Bool
    public let screenRecordingTrusted: Bool
}

public struct PermissionGate {
    private let checker: any PermissionChecking

    public init(checker: any PermissionChecking) {
        self.checker = checker
    }

    public func status(includeScreenshot: Bool, prompt: Bool) -> PermissionStatus {
        let accessibility = checker.accessibilityTrusted(prompt: prompt)
        let screenRecording = includeScreenshot
            ? checker.screenRecordingTrusted(prompt: prompt)
            : true
        return PermissionStatus(
            accessibilityTrusted: accessibility,
            screenRecordingTrusted: screenRecording
        )
    }

    public func require(includeScreenshot: Bool, prompt: Bool) throws {
        let current = status(includeScreenshot: includeScreenshot, prompt: prompt)
        var missing: [String] = []
        if !current.accessibilityTrusted {
            missing.append("Accessibility")
        }
        if includeScreenshot && !current.screenRecordingTrusted {
            missing.append("Screen Recording")
        }
        guard missing.isEmpty else {
            throw HelperError(
                code: "permission_denied",
                message: "Grant \(missing.joined(separator: " and ")) permission to BladeComputerUseHelper in System Settings > Privacy & Security, then retry."
            )
        }
    }
}
