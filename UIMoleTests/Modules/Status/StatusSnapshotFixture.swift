import Foundation
@testable import UIMole

extension StatusSnapshot {

    static func fixture(
        host: String = "test-host",
        healthScore: Int = 100
    ) -> StatusSnapshot {
        StatusSnapshot(
            collectedAt: "2026-04-21T00:00:00Z",
            host: host,
            platform: "darwin 26.2",
            uptime: "1h",
            hardware: Hardware(
                model: "Test Mac",
                cpuModel: "Apple M0",
                totalRam: "16 GB",
                diskSize: "256 GB",
                osVersion: "macOS 99.0"
            ),
            healthScore: healthScore,
            healthScoreMsg: "OK",
            cpu: CPU(
                usage: 10,
                perCore: [10, 20],
                load1: 0.1,
                load5: 0.2,
                load15: 0.3,
                coreCount: 2,
                pCoreCount: 1,
                eCoreCount: 1
            ),
            memory: Memory(
                used: 1_000,
                total: 10_000,
                usedPercent: 10,
                swapUsed: 0,
                swapTotal: 0
            ),
            disks: [],
            diskIo: DiskIO(readRate: 0, writeRate: 0),
            network: [],
            proxy: nil,
            batteries: [],
            thermal: Thermal(batteryTemp: 0),
            topProcesses: []
        )
    }
}
