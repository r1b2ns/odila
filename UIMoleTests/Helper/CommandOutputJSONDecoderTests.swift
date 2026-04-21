import Foundation
import Testing
@testable import UIMole

struct CommandOutputJSONDecoderTests {

    private struct Sample: Decodable, Equatable {
        let name: String
        let value: Int
    }

    @Test
    func decodesWellFormedJSON() throws {
        let sut = CommandOutputJSONDecoder()
        let result = try sut.decode(Sample.self, from: #"{"name":"foo","value":42}"#)
        #expect(result == Sample(name: "foo", value: 42))
    }

    @Test
    func stripsLeadingAndTrailingNoise() throws {
        let sut = CommandOutputJSONDecoder()
        let output = """
        some log line
        {"name":"foo","value":42}
        trailing garbage
        """
        let result = try sut.decode(Sample.self, from: output)
        #expect(result == Sample(name: "foo", value: 42))
    }

    @Test
    func decodesArrayRoot() throws {
        let sut = CommandOutputJSONDecoder()
        let result = try sut.decode([Int].self, from: "[1,2,3]")
        #expect(result == [1, 2, 3])
    }

    @Test
    func throwsOnEmptyOutput() {
        let sut = CommandOutputJSONDecoder()
        #expect(throws: CommandOutputJSONDecoderError.emptyOutput) {
            _ = try sut.decode(Sample.self, from: "   \n\t  ")
        }
    }

    @Test
    func throwsWhenNoJSONFound() {
        let sut = CommandOutputJSONDecoder()
        #expect(throws: CommandOutputJSONDecoderError.jsonNotFound) {
            _ = try sut.decode(Sample.self, from: "just a log line, no braces")
        }
    }

    @Test
    func throwsOnMalformedJSON() {
        let sut = CommandOutputJSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try sut.decode(Sample.self, from: "{name: foo}")
        }
    }
}
