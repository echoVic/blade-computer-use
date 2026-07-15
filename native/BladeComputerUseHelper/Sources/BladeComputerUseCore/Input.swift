import Foundation

public enum KeyMap {
    private static let keyCodes: [String: UInt16] = [
        "return": 36,
        "enter": 36,
        "tab": 48,
        "space": 49,
        "delete": 51,
        "backspace": 51,
        "escape": 53,
        "left": 123,
        "right": 124,
        "down": 125,
        "up": 126,
        "home": 115,
        "end": 119,
        "page_up": 116,
        "page_down": 121,
        "f1": 122,
        "f2": 120,
        "f3": 99,
        "f4": 118,
        "f5": 96,
        "f6": 97,
        "f7": 98,
        "f8": 100,
        "f9": 101,
        "f10": 109,
        "f11": 103,
        "f12": 111,
    ]

    public static func keyCode(for key: String) -> UInt16? {
        keyCodes[key.lowercased()]
    }
}

public func isSecureRole(_ role: String) -> Bool {
    role == "AXSecureTextField" || role == "AXSecureTextArea"
}
