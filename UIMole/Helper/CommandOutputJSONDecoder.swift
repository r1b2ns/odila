import Foundation

enum CommandOutputJSONDecoderError: Error, Equatable {
    case emptyOutput
    case jsonNotFound
    case invalidUTF8
}

struct CommandOutputJSONDecoder: Sendable {

    private let decoder: JSONDecoder

    init(decoder: JSONDecoder? = nil) {
        if let decoder {
            self.decoder = decoder
        } else {
            let defaultDecoder = JSONDecoder()
            defaultDecoder.keyDecodingStrategy = .convertFromSnakeCase
            self.decoder = defaultDecoder
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from output: String) throws -> T {
        let data = try extractJSONData(from: output)
        return try decoder.decode(T.self, from: data)
    }

    private func extractJSONData(from output: String) throws -> Data {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CommandOutputJSONDecoderError.emptyOutput
        }

        guard
            let start = trimmed.firstIndex(where: { $0 == "{" || $0 == "[" }),
            let end = trimmed.lastIndex(where: { $0 == "}" || $0 == "]" }),
            start < end
        else {
            throw CommandOutputJSONDecoderError.jsonNotFound
        }

        let slice = trimmed[start...end]
        guard let data = slice.data(using: .utf8) else {
            throw CommandOutputJSONDecoderError.invalidUTF8
        }
        return data
    }
}
