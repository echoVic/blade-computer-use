import Foundation
import BladeComputerUseCore

let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

while let line = readLine() {
    let response: HelperResponse
    do {
        let request = try decoder.decode(HelperRequest.self, from: Data(line.utf8))
        response = HelperResponse(
            id: request.id,
            result: .object([
                "method": .string(request.method),
                "params": .object(request.params),
            ]),
            error: nil
        )
    } catch {
        response = HelperResponse(
            id: "unknown",
            result: nil,
            error: HelperError(code: "invalid_request", message: error.localizedDescription)
        )
    }

    if let data = try? encoder.encode(response), let output = String(data: data, encoding: .utf8) {
        print(output)
        fflush(stdout)
    }
}
