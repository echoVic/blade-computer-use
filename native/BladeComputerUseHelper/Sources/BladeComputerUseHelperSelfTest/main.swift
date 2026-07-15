import Foundation
import BladeComputerUseCore

final class RecordingPermissionChecker: PermissionChecking {
    let accessibilityResult: Bool
    let screenRecordingResult: Bool
    var accessibilityPrompts: [Bool] = []
    var screenRecordingPrompts: [Bool] = []

    init(accessibilityResult: Bool, screenRecordingResult: Bool) {
        self.accessibilityResult = accessibilityResult
        self.screenRecordingResult = screenRecordingResult
    }

    func accessibilityTrusted(prompt: Bool) -> Bool {
        accessibilityPrompts.append(prompt)
        return accessibilityResult
    }

    func screenRecordingTrusted(prompt: Bool) -> Bool {
        screenRecordingPrompts.append(prompt)
        return screenRecordingResult
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("self-test failed: \(message)\n".utf8))
        exit(1)
    }
}

do {
    let request = HelperRequest(
        id: "1",
        method: "list_apps",
        params: ["include_screenshot": .bool(true)]
    )
    let requestData = try JSONEncoder().encode(request)
    let decodedRequest = try JSONDecoder().decode(HelperRequest.self, from: requestData)
    require(decodedRequest == request, "request round trip")

    let response = HelperResponse(
        id: "2",
        result: nil,
        error: HelperError(code: "stale_revision", message: "Observe again")
    )
    let responseData = try JSONEncoder().encode(response)
    let decodedResponse = try JSONDecoder().decode(HelperResponse.self, from: responseData)
    require(decodedResponse == response, "response round trip")

    let tree = TreeNode(
        token: 10,
        role: "AXWindow",
        title: "Document",
        children: [
            TreeNode(token: 11, role: "AXButton", title: "Save"),
            TreeNode(
                token: 12,
                role: "AXGroup",
                children: [TreeNode(token: 13, role: "AXStaticText", title: "Deep")]
            ),
        ]
    )
    let serialized = BoundedTreeSerializer(maxDepth: 1, maxNodes: 3).serialize(tree)
    require(serialized.lines.count == 3, "tree node limit")
    require(serialized.lines[0].contains("[0] AXWindow"), "root index")
    require(serialized.lines[1].contains("[1] AXButton"), "child index")
    require(serialized.indexToToken[1] == 11, "index to token mapping")
    require(serialized.truncated, "depth truncation marker")

    require(KeyMap.keyCode(for: "return") == 36, "Return key mapping")
    require(KeyMap.keyCode(for: "escape") == 53, "Escape key mapping")
    require(KeyMap.keyCode(for: "left") == 123, "Left arrow mapping")
    require(KeyMap.keyCode(for: "unknown") == nil, "unsupported key mapping")
    require(isSecureRole("AXSecureTextField"), "secure role detection")
    require(!isSecureRole("AXTextField"), "normal text field detection")

    let deniedPermissions = RecordingPermissionChecker(
        accessibilityResult: false,
        screenRecordingResult: false
    )
    do {
        try PermissionGate(checker: deniedPermissions).require(
            includeScreenshot: true,
            prompt: true
        )
        require(false, "missing permission rejection")
    } catch let error as HelperError {
        require(error.code == "permission_denied", "permission error code")
        require(error.message.contains("Accessibility"), "accessibility error detail")
        require(error.message.contains("Screen Recording"), "screen recording error detail")
    }
    require(deniedPermissions.accessibilityPrompts == [true], "accessibility prompt request")
    require(deniedPermissions.screenRecordingPrompts == [true], "screen recording prompt request")

    let accessibilityOnly = RecordingPermissionChecker(
        accessibilityResult: false,
        screenRecordingResult: false
    )
    try? PermissionGate(checker: accessibilityOnly).require(
        includeScreenshot: false,
        prompt: true
    )
    require(accessibilityOnly.accessibilityPrompts == [true], "AX-only prompt request")
    require(accessibilityOnly.screenRecordingPrompts.isEmpty, "skip unused screen permission")

    let point = try WindowCoordinates.absolute(
        x: 10,
        y: 15,
        in: TreeFrame(x: 100, y: 200, width: 300, height: 400)
    )
    require(point.x == 110 && point.y == 215, "window-relative coordinate conversion")
    do {
        _ = try WindowCoordinates.absolute(
            x: 301,
            y: 15,
            in: TreeFrame(x: 100, y: 200, width: 300, height: 400)
        )
        require(false, "out-of-bounds coordinate rejection")
    } catch let error as HelperError {
        require(error.code == "invalid_request", "coordinate error code")
    }

    print("BladeComputerUseHelperSelfTest: 22 checks passed")
} catch {
    FileHandle.standardError.write(Data("self-test failed: \(error)\n".utf8))
    exit(1)
}
