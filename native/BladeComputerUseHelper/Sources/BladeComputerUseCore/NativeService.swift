import AppKit
import ApplicationServices
import Foundation

private struct NativeSnapshot {
    let revision: String
    let processID: pid_t
    let window: AXUIElement
    let bounds: TreeFrame
    let elements: [Int: AXUIElement]
}

@MainActor
public final class NativeService {
    private let reader = AXTreeReader()
    private var snapshots: [String: NativeSnapshot] = [:]

    public init() {}

    public func handle(method: String, params: [String: JSONValue]) async throws -> JSONValue {
        switch method {
        case "list_apps": return listApps()
        case "observe": return try await observe(params)
        case "click": return try click(params)
        case "type_text": return try typeText(params)
        case "press_key": return try pressKey(params)
        case "scroll": return try scroll(params)
        default:
            throw HelperError(code: "invalid_request", message: "Unknown helper method: \(method)")
        }
    }

    private func listApps() -> JSONValue {
        let trusted = AXIsProcessTrusted()
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
            .map { app in
                JSONValue.object([
                    "name": .string(app.localizedName ?? app.bundleIdentifier ?? "Unknown"),
                    "bundle_id": .string(app.bundleIdentifier ?? ""),
                    "pid": .number(Double(app.processIdentifier)),
                    "has_window": .bool(trusted && reader.hasWindow(processID: app.processIdentifier)),
                ])
            }
        return .object(["apps": .array(apps), "accessibility_trusted": .bool(trusted)])
    }

    private func observe(_ params: [String: JSONValue]) async throws -> JSONValue {
        try requireAccessibility()
        let appID = try params.requiredString("app")
        let app = try application(bundleID: appID)
        let observation = try reader.observe(processID: app.processIdentifier)
        let revision = UUID().uuidString.lowercased()
        snapshots[appID] = NativeSnapshot(
            revision: revision,
            processID: app.processIdentifier,
            window: observation.window,
            bounds: observation.windowBounds,
            elements: observation.elements
        )

        var result: [String: JSONValue] = [
            "app": .string(appID),
            "name": .string(app.localizedName ?? appID),
            "revision": .string(revision),
            "window": .object([
                "title": .string(observation.windowTitle),
                "bounds": frameJSON(observation.windowBounds),
            ]),
            "ax_tree": .string(observation.tree.lines.joined(separator: "\n")),
            "truncated": .bool(observation.tree.truncated),
        ]
        if params["include_screenshot"]?.boolValue ?? true {
            result["screenshot_path"] = .string(
                try await WindowScreenshot.capture(
                    processID: app.processIdentifier,
                    title: observation.windowTitle
                )
            )
        }
        return .object(result)
    }

    private func click(_ params: [String: JSONValue]) throws -> JSONValue {
        let (appID, revision, snapshot) = try consume(params)
        let point: ScreenPoint
        if let elementNumber = params["element_index"]?.numberValue {
            let index = Int(elementNumber)
            guard let element = snapshot.elements[index], let frame = reader.frame(of: element) else {
                throw HelperError(code: "stale_revision", message: "Element \(index) is unavailable.")
            }
            point = ScreenPoint(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
        } else {
            try validateWindow(snapshot)
            point = try WindowCoordinates.absolute(
                x: try params.requiredNumber("x"),
                y: try params.requiredNumber("y"),
                in: snapshot.bounds
            )
        }
        activate(appID)
        try NativeInput.click(
            point: point,
            button: params["button"]?.stringValue ?? "left",
            count: Int(params["click_count"]?.numberValue ?? 1)
        )
        return actionResult(revision)
    }

    private func typeText(_ params: [String: JSONValue]) throws -> JSONValue {
        let (appID, revision, snapshot) = try consume(params)
        guard let focused = reader.focusedElement(processID: snapshot.processID) else {
            throw HelperError(code: "stale_revision", message: "No focused element is available.")
        }
        let role = reader.role(of: focused)
        guard !isSecureRole(role) else {
            throw HelperError(code: "secure_input_denied", message: "Typing into secure fields is denied.")
        }
        activate(appID)
        NativeInput.typeText(try params.requiredString("text"))
        return actionResult(revision)
    }

    private func pressKey(_ params: [String: JSONValue]) throws -> JSONValue {
        let (appID, revision, _) = try consume(params)
        let modifiers = params["modifiers"]?.arrayValue?.compactMap(\.stringValue) ?? []
        activate(appID)
        try NativeInput.pressKey(try params.requiredString("key"), modifiers: modifiers)
        return actionResult(revision)
    }

    private func scroll(_ params: [String: JSONValue]) throws -> JSONValue {
        let (appID, revision, snapshot) = try consume(params)
        let point: ScreenPoint
        if let elementNumber = params["element_index"]?.numberValue,
           let element = snapshot.elements[Int(elementNumber)],
           let frame = reader.frame(of: element) {
            point = ScreenPoint(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
        } else if let x = params["x"]?.numberValue, let y = params["y"]?.numberValue {
            try validateWindow(snapshot)
            point = try WindowCoordinates.absolute(x: x, y: y, in: snapshot.bounds)
        } else {
            point = ScreenPoint(
                x: snapshot.bounds.x + snapshot.bounds.width / 2,
                y: snapshot.bounds.y + snapshot.bounds.height / 2
            )
        }
        activate(appID)
        NativeInput.scroll(
            point: point,
            deltaX: params["delta_x"]?.numberValue ?? 0,
            deltaY: try params.requiredNumber("delta_y")
        )
        return actionResult(revision)
    }

    private func consume(_ params: [String: JSONValue]) throws -> (String, String, NativeSnapshot) {
        let appID = try params.requiredString("app")
        let revision = try params.requiredString("revision")
        guard let snapshot = snapshots[appID], snapshot.revision == revision else {
            throw HelperError(code: "stale_revision", message: "Observe \(appID) again before acting.")
        }
        snapshots.removeValue(forKey: appID)
        return (appID, revision, snapshot)
    }

    private func validateWindow(_ snapshot: NativeSnapshot) throws {
        guard let current = reader.frame(of: snapshot.window) else {
            throw HelperError(code: "stale_revision", message: "The observed window is no longer available.")
        }
        let values = [current.x - snapshot.bounds.x, current.y - snapshot.bounds.y, current.width - snapshot.bounds.width, current.height - snapshot.bounds.height]
        guard values.allSatisfy({ abs($0) <= 1 }) else {
            throw HelperError(code: "stale_revision", message: "The window moved or resized. Observe again.")
        }
    }

    private func application(bundleID: String) throws -> NSRunningApplication {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            throw HelperError(code: "app_not_found", message: "App \(bundleID) is not running.")
        }
        return app
    }

    private func activate(_ bundleID: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.activate()
    }

    private func requireAccessibility() throws {
        guard AXIsProcessTrusted() else {
            throw HelperError(
                code: "permission_denied",
                message: "Accessibility permission is required for the current terminal or agent host."
            )
        }
    }

    private func frameJSON(_ frame: TreeFrame) -> JSONValue {
        .object([
            "x": .number(frame.x),
            "y": .number(frame.y),
            "width": .number(frame.width),
            "height": .number(frame.height),
        ])
    }

    private func actionResult(_ revision: String) -> JSONValue {
        .object(["ok": .bool(true), "revision_consumed": .string(revision)])
    }
}
