import Foundation

enum MoleBinaryLocatorError: Error, Equatable {
    case binaryNotFound(String)
}

enum MoleBinaryLocator {

    static func url(for binary: String, bundle: Bundle = .main) throws -> URL {
        guard let url = bundle.url(
            forResource: binary,
            withExtension: nil,
            subdirectory: "mole"
        ) else {
            throw MoleBinaryLocatorError.binaryNotFound(binary)
        }
        return url
    }
}
