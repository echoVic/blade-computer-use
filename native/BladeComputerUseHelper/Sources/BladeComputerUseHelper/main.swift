import Foundation
import BladeComputerUseCore

let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
let service = NativeService()

while let line = readLine() {
    let response: HelperResponse
    do {
        let request = try decoder.decode(HelperRequest.self, from: Data(line.utf8))
        let result = try await service.handle(method: request.method, params: request.params)
        response = HelperResponse(
            id: request.id,
            result: result,
            error: nil
        )
    } catch let error as HelperError {
        let requestID = (try? decoder.decode(HelperRequest.self, from: Data(line.utf8)))?.id ?? "unknown"
        response = HelperResponse(id: requestID, result: nil, error: error)
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
