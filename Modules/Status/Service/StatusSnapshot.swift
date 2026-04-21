import Foundation

struct StatusSnapshot: Decodable, Sendable, Equatable {

    let collectedAt: String
    let host: String
    let platform: String
    let uptime: String
    let hardware: Hardware
    let healthScore: Int
    let healthScoreMsg: String
    let cpu: CPU
    let memory: Memory
    let disks: [Disk]
    let diskIo: DiskIO
    let network: [Network]
    let proxy: Proxy?
    let batteries: [Battery]
    let thermal: Thermal
    let topProcesses: [TopProcess]

    struct Hardware: Decodable, Sendable, Equatable {
        let model: String
        let cpuModel: String
        let totalRam: String
        let diskSize: String
        let osVersion: String
    }

    struct CPU: Decodable, Sendable, Equatable {
        let usage: Double
        let perCore: [Double]
        let load1: Double
        let load5: Double
        let load15: Double
        let coreCount: Int
        let pCoreCount: Int
        let eCoreCount: Int
    }

    struct Memory: Decodable, Sendable, Equatable {
        let used: Int64
        let total: Int64
        let usedPercent: Double
        let swapUsed: Int64
        let swapTotal: Int64
    }

    struct Disk: Decodable, Sendable, Equatable, Identifiable {
        let mount: String
        let device: String
        let used: Int64
        let total: Int64
        let usedPercent: Double
        let external: Bool

        var id: String { device }
    }

    struct DiskIO: Decodable, Sendable, Equatable {
        let readRate: Double
        let writeRate: Double
    }

    struct Network: Decodable, Sendable, Equatable, Identifiable {
        let name: String
        let rxRateMbs: Double
        let txRateMbs: Double
        let ip: String

        var id: String { name }
    }

    struct Proxy: Decodable, Sendable, Equatable {
        let enabled: Bool
        let type: String
        let host: String
    }

    struct Battery: Decodable, Sendable, Equatable {
        let percent: Int
        let status: String
        let timeLeft: String
        let health: String
        let cycleCount: Int
        let capacity: Int
    }

    struct Thermal: Decodable, Sendable, Equatable {
        let batteryTemp: Double
    }

    struct TopProcess: Decodable, Sendable, Equatable, Identifiable {
        let pid: Int
        let name: String
        let cpu: Double
        let memory: Double

        var id: Int { pid }
    }
}
