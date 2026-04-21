import Foundation

struct CommandResult: Sendable, Equatable {
    let output: String
    let error: String
    let exitCode: Int32

    var isSuccess: Bool { exitCode == 0 }
}
