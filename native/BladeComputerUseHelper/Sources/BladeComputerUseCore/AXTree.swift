import Foundation

public struct TreeFrame: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct TreeNode: Equatable, Sendable {
    public let token: Int
    public let role: String
    public let title: String?
    public let value: String?
    public let frame: TreeFrame?
    public let children: [TreeNode]

    public init(
        token: Int,
        role: String,
        title: String? = nil,
        value: String? = nil,
        frame: TreeFrame? = nil,
        children: [TreeNode] = []
    ) {
        self.token = token
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
        self.children = children
    }
}

public struct SerializedTree: Equatable, Sendable {
    public let lines: [String]
    public let indexToToken: [Int: Int]
    public let truncated: Bool
}

public struct BoundedTreeSerializer: Sendable {
    public let maxDepth: Int
    public let maxNodes: Int

    public init(maxDepth: Int = 12, maxNodes: Int = 500) {
        self.maxDepth = maxDepth
        self.maxNodes = maxNodes
    }

    public func serialize(_ root: TreeNode) -> SerializedTree {
        var lines: [String] = []
        var indexToToken: [Int: Int] = [:]
        var truncated = false

        func visit(_ node: TreeNode, depth: Int) {
            guard lines.count < maxNodes else {
                truncated = true
                return
            }
            guard depth <= maxDepth else {
                truncated = true
                return
            }

            let index = lines.count
            indexToToken[index] = node.token
            lines.append(format(node, index: index, depth: depth))

            if depth == maxDepth, !node.children.isEmpty {
                truncated = true
                return
            }
            for child in node.children {
                visit(child, depth: depth + 1)
            }
        }

        visit(root, depth: 0)
        return SerializedTree(lines: lines, indexToToken: indexToToken, truncated: truncated)
    }

    private func format(_ node: TreeNode, index: Int, depth: Int) -> String {
        var parts = [String(repeating: "  ", count: depth) + "[\(index)] \(node.role)"]
        if let title = cleaned(node.title), !title.isEmpty {
            parts.append("title=\"\(title)\"")
        }
        if let value = cleaned(node.value), !value.isEmpty {
            parts.append("value=\"\(value)\"")
        }
        if let frame = node.frame {
            parts.append(
                "frame=(\(integer(frame.x)),\(integer(frame.y)),\(integer(frame.width)),\(integer(frame.height)))"
            )
        }
        return parts.joined(separator: " ")
    }

    private func cleaned(_ value: String?) -> String? {
        value?
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .prefix(160)
            .description
    }

    private func integer(_ value: Double) -> Int {
        Int(value.rounded())
    }
}
