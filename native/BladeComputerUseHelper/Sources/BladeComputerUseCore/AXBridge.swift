import AppKit
import ApplicationServices
import Foundation

struct AXObservation {
    let window: AXUIElement
    let windowTitle: String
    let windowBounds: TreeFrame
    let tree: SerializedTree
    let elements: [Int: AXUIElement]
}

final class AXTreeReader {
    private var nextToken = 0
    private var tokenElements: [Int: AXUIElement] = [:]
    private var visited: Set<CFHashCode> = []

    func observe(processID: pid_t) throws -> AXObservation {
        nextToken = 0
        tokenElements = [:]
        visited = []

        let application = AXUIElementCreateApplication(processID)
        let window = try focusedWindow(of: application)
        guard let bounds = frame(of: window) else {
            throw HelperError(code: "window_not_found", message: "The focused window has no bounds.")
        }
        guard let root = buildNode(window, depth: 0, maxDepth: 12) else {
            throw HelperError(code: "window_not_found", message: "The focused window is not accessible.")
        }

        let tree = BoundedTreeSerializer(maxDepth: 12, maxNodes: 500).serialize(root)
        var indexedElements: [Int: AXUIElement] = [:]
        for (index, token) in tree.indexToToken {
            if let element = tokenElements[token] {
                indexedElements[index] = element
            }
        }

        return AXObservation(
            window: window,
            windowTitle: stringAttribute(window, kAXTitleAttribute) ?? "",
            windowBounds: bounds,
            tree: tree,
            elements: indexedElements
        )
    }

    func frame(of element: AXUIElement) -> TreeFrame? {
        guard
            let positionValue = attribute(element, kAXPositionAttribute),
            let sizeValue = attribute(element, kAXSizeAttribute),
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else {
            return nil
        }
        return TreeFrame(
            x: point.x,
            y: point.y,
            width: size.width,
            height: size.height
        )
    }

    func role(of element: AXUIElement) -> String {
        stringAttribute(element, kAXRoleAttribute) ?? "AXUnknown"
    }

    func value(of element: AXUIElement) -> String? {
        displayValue(attribute(element, kAXValueAttribute))
    }

    func selectedTextLength(of element: AXUIElement) -> Int? {
        guard
            let value = attribute(element, kAXSelectedTextRangeAttribute),
            CFGetTypeID(value) == AXValueGetTypeID(),
            AXValueGetType(value as! AXValue) == .cfRange
        else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else {
            return nil
        }
        return range.length
    }

    func waitForValueChange(
        of element: AXUIElement,
        from initialValue: String,
        expectedUTF16Count: Int?,
        timeout: TimeInterval = 2,
        quietPeriod: TimeInterval = 0.15
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastValue = initialValue
        var lastChange: Date?

        while Date() < deadline {
            if let currentValue = value(of: element), currentValue != lastValue {
                lastValue = currentValue
                lastChange = Date()
            }
            let reachedExpectedLength = expectedUTF16Count.map {
                lastValue.utf16.count == $0
            } ?? true
            if lastValue != initialValue,
               reachedExpectedLength,
               let lastChange,
               Date().timeIntervalSince(lastChange) >= quietPeriod {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return lastValue != initialValue
    }

    func focusedElement(processID: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(processID)
        return elementAttribute(app, kAXFocusedUIElementAttribute)
    }

    func hasWindow(processID: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(processID)
        return elementAttribute(app, kAXFocusedWindowAttribute) != nil || !elementArrayAttribute(app, kAXWindowsAttribute).isEmpty
    }

    private func focusedWindow(of app: AXUIElement) throws -> AXUIElement {
        if let focused = elementAttribute(app, kAXFocusedWindowAttribute) {
            return focused
        }
        if let first = elementArrayAttribute(app, kAXWindowsAttribute).first {
            return first
        }
        throw HelperError(code: "window_not_found", message: "The app has no accessible window.")
    }

    private func buildNode(_ element: AXUIElement, depth: Int, maxDepth: Int) -> TreeNode? {
        guard depth <= maxDepth else { return nil }
        let hash = CFHash(element)
        guard visited.insert(hash).inserted else { return nil }

        if let hidden = attribute(element, kAXHiddenAttribute) as? Bool, hidden {
            return nil
        }

        let token = nextToken
        nextToken += 1
        tokenElements[token] = element

        let role = self.role(of: element)
        let title = stringAttribute(element, kAXTitleAttribute)
            ?? stringAttribute(element, kAXDescriptionAttribute)
        let value = isSecureRole(role) ? nil : displayValue(attribute(element, kAXValueAttribute))

        var children: [TreeNode] = []
        if depth < maxDepth {
            for child in elementArrayAttribute(element, kAXChildrenAttribute) {
                if let node = buildNode(child, depth: depth + 1, maxDepth: maxDepth) {
                    children.append(node)
                }
            }
        } else if !elementArrayAttribute(element, kAXChildrenAttribute).isEmpty {
            children.append(TreeNode(token: nextToken, role: "AXTruncated"))
        }

        return TreeNode(
            token: token,
            role: role,
            title: title,
            value: value,
            frame: frame(of: element),
            children: children
        )
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    private func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func elementArrayAttribute(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
        guard let values = attribute(element, name) as? [AnyObject] else { return [] }
        return values.compactMap { value in
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            return (value as! AXUIElement)
        }
    }

    private func displayValue(_ value: CFTypeRef?) -> String? {
        guard let value else { return nil }
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }
}
