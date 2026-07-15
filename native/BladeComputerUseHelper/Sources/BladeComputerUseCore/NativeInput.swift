import ApplicationServices
import Foundation

enum NativeInput {
    static func click(point: ScreenPoint, button: String, count: Int) throws {
        let mouseButton: CGMouseButton
        let downType: CGEventType
        let upType: CGEventType
        switch button {
        case "left":
            mouseButton = .left
            downType = .leftMouseDown
            upType = .leftMouseUp
        case "right":
            mouseButton = .right
            downType = .rightMouseDown
            upType = .rightMouseUp
        default:
            throw HelperError(code: "invalid_request", message: "Unsupported mouse button: \(button)")
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let location = CGPoint(x: point.x, y: point.y)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: location, mouseButton: mouseButton)?.post(tap: .cghidEventTap)
        for clickNumber in 1...max(1, min(count, 2)) {
            let down = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: location, mouseButton: mouseButton)
            down?.setIntegerValueField(.mouseEventClickState, value: Int64(clickNumber))
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: location, mouseButton: mouseButton)
            up?.setIntegerValueField(.mouseEventClickState, value: Int64(clickNumber))
            up?.post(tap: .cghidEventTap)
        }
    }

    static func typeText(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        let units = Array(text.utf16)
        let chunkSize = 20
        for offset in stride(from: 0, to: units.count, by: chunkSize) {
            let chunk = Array(units[offset..<min(offset + chunkSize, units.count)])
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            chunk.withUnsafeBufferPointer { pointer in
                down?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: pointer.baseAddress!)
            }
            down?.post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)?.post(tap: .cghidEventTap)
        }
    }

    static func pressKey(_ key: String, modifiers: [String]) throws {
        guard let code = KeyMap.keyCode(for: key) else {
            throw HelperError(code: "unsupported_key", message: "Unsupported key: \(key)")
        }
        var flags: CGEventFlags = []
        for modifier in modifiers.map({ $0.lowercased() }) {
            switch modifier {
            case "command", "cmd": flags.insert(.maskCommand)
            case "control", "ctrl": flags.insert(.maskControl)
            case "option", "alt": flags.insert(.maskAlternate)
            case "shift": flags.insert(.maskShift)
            default:
                throw HelperError(code: "invalid_request", message: "Unsupported modifier: \(modifier)")
            }
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    static func scroll(point: ScreenPoint, deltaX: Double, deltaY: Double) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: point.x, y: point.y), mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY.rounded()),
            wheel2: Int32(deltaX.rounded()),
            wheel3: 0
        )?.post(tap: .cghidEventTap)
    }
}
