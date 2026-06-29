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
    public let pressure: MemoryPressureLevel

    public init(usedBytes: UInt64, totalBytes: UInt64, pressure: MemoryPressureLevel = .normal) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
    }

    public var percentage: Double {
        Percentage(used: Double(usedBytes), total: Double(totalBytes)).value
    }
}

public enum MemoryPressureLevel: Equatable {
    case normal
    case warning
    case critical
    case unknown
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

    public static func compactRate(_ bytesPerSecond: UInt64) -> String {
        leftPad(compactBytes(bytesPerSecond), to: 5)
    }

    public static func memoryPressure(_ level: MemoryPressureLevel) -> String {
        switch level {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        case .unknown:
            return "Unknown"
        }
    }

    public static func compactMemoryPressure(_ level: MemoryPressureLevel) -> String {
        switch level {
        case .normal:
            return " Low"
        case .warning:
            return " Mid"
        case .critical:
            return "High"
        case .unknown:
            return "  --"
        }
    }

    public static func menuTitle(for snapshot: SystemSnapshot) -> String {
        let memoryRow = menuRow(
            leftLabel: "MEM USE",
            leftValue: leftPad(percent(snapshot.memory.percentage), to: 4),
            rightLabel: "↑",
            rightValue: compactRate(snapshot.network.transmitBytesPerSecond)
        )
        let pressureRow = menuRow(
            leftLabel: "MEM PRES",
            leftValue: compactMemoryPressure(snapshot.memory.pressure),
            rightLabel: "↓",
            rightValue: compactRate(snapshot.network.receiveBytesPerSecond)
        )

        return "\(memoryRow)\n\(pressureRow)"
    }

    private static func compactBytes(_ bytes: UInt64) -> String {
        let units = ["B", "K", "M", "G", "T"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(value))\(units[unitIndex])"
        }

        let rounded = (value * 10).rounded() / 10
        if rounded >= 100 || rounded.rounded() == rounded {
            return "\(Int(rounded.rounded()))\(units[unitIndex])"
        }
        return String(format: "%.1f%@", rounded, units[unitIndex])
    }

    private static func leftPad(_ value: String, to width: Int) -> String {
        let padding = max(0, width - value.count)
        return String(repeating: " ", count: padding) + value
    }

    private static func rightPad(_ value: String, to width: Int) -> String {
        let padding = max(0, width - value.count)
        return value + String(repeating: " ", count: padding)
    }

    private static func menuRow(
        leftLabel: String,
        leftValue: String,
        rightLabel: String,
        rightValue: String
    ) -> String {
        "\(rightPad(leftLabel, to: 8)) \(leftValue)   \(rightLabel) \(rightValue)"
    }
}
