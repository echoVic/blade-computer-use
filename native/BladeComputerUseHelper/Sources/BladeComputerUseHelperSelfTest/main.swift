import Foundation
import BladeComputerUseCore

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
    print("BladeComputerUseHelperSelfTest: 2 checks passed")
} catch {
    FileHandle.standardError.write(Data("self-test failed: \(error)\n".utf8))
    exit(1)
}
