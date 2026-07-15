import Foundation

public struct ScreenPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum WindowCoordinates {
    public static func absolute(x: Double, y: Double, in bounds: TreeFrame) throws -> ScreenPoint {
        guard x >= 0, y >= 0, x <= bounds.width, y <= bounds.height else {
            throw HelperError(
                code: "invalid_request",
                message: "Coordinate (\(x), \(y)) is outside the observed window."
            )
        }
        return ScreenPoint(x: bounds.x + x, y: bounds.y + y)
    }
}

public extension JSONValue {
    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }
}

public extension Dictionary where Key == String, Value == JSONValue {
    func requiredString(_ key: String) throws -> String {
        guard let value = self[key]?.stringValue, !value.isEmpty else {
            throw HelperError(code: "invalid_request", message: "Missing string parameter: \(key)")
        }
        return value
    }

    func requiredNumber(_ key: String) throws -> Double {
        guard let value = self[key]?.numberValue else {
            throw HelperError(code: "invalid_request", message: "Missing number parameter: \(key)")
        }
        return value
    }
}
