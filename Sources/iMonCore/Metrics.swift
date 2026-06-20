import Foundation

public struct Percentage: Equatable {
    public let value: Double

    public init(used: Double, total: Double) {
        guard total > 0 else {
            self.value = 0
            return
        }
        self.value = min(100, max(0, used / total * 100))
    }
}

public struct CPUUsage: Equatable {
    public let user: Double
    public let system: Double
    public let idle: Double

    public init(user: Double, system: Double, idle: Double) {
        self.user = min(100, max(0, user))
        self.system = min(100, max(0, system))
        self.idle = min(100, max(0, idle))
    }

    public var active: Double {
        min(100, max(0, user + system))
    }
}

public struct MemoryUsage: Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    public var percentage: Double {
        Percentage(used: Double(usedBytes), total: Double(totalBytes)).value
    }
}

public struct DiskUsage: Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    public var percentage: Double {
        Percentage(used: Double(usedBytes), total: Double(totalBytes)).value
    }
}

public struct NetworkRate: Equatable {
    public let receiveBytesPerSecond: UInt64
    public let transmitBytesPerSecond: UInt64

    public init(receiveBytesPerSecond: UInt64, transmitBytesPerSecond: UInt64) {
        self.receiveBytesPerSecond = receiveBytesPerSecond
        self.transmitBytesPerSecond = transmitBytesPerSecond
    }
}

public struct SystemSnapshot: Equatable {
    public let timestamp: Date
    public let cpu: CPUUsage
    public let memory: MemoryUsage
    public let disk: DiskUsage
    public let network: NetworkRate

    public init(timestamp: Date, cpu: CPUUsage, memory: MemoryUsage, disk: DiskUsage, network: NetworkRate) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
    }
}

public enum MetricFormatter {
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func bytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        }

        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(Int(rounded)) \(units[unitIndex])"
        }
        return String(format: "%.1f %@", rounded, units[unitIndex])
    }

    public static func rate(_ bytesPerSecond: UInt64) -> String {
        "\(bytes(bytesPerSecond))/s"
    }

    public static func menuTitle(for snapshot: SystemSnapshot) -> String {
        "CPU \(percent(snapshot.cpu.active)) MEM \(percent(snapshot.memory.percentage)) v \(rate(snapshot.network.receiveBytesPerSecond)) ^ \(rate(snapshot.network.transmitBytesPerSecond))"
    }
}
