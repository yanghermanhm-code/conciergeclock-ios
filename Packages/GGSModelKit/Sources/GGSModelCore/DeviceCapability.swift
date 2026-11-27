import Foundation

/// Which model this iPhone can run, from its physical memory.
///
///  - 8 GB (iPhone 15 Pro and newer): Gemma 4 E4B on the GPU.
///  - 6 GB (e.g. iPhone 14 Pro, 15): Gemma 4 E2B on the GPU. E4B can still be chosen; it
///    then runs on the CPU (about 1 GB of working memory, but several times slower).
///  - Less: no model; apps use their built-in features.
public struct DeviceCapability: Sendable, Hashable {
    public var memoryGB: Double

    public init(memoryGB: Double) {
        self.memoryGB = memoryGB
    }

    public static var current: DeviceCapability {
        DeviceCapability(memoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824)
    }

    /// The model to offer by default, or nil when this iPhone should not run one.
    public var recommendedModel: ModelSpec? {
        ModelCatalog.all.first { memoryGB >= $0.minimumMemoryGB }
    }

    /// Any catalog model runs on a 6 GB iPhone or better (a large one on the CPU if needed).
    public func canRun(_ spec: ModelSpec) -> Bool {
        memoryGB >= ModelCatalog.gemma4E2B.minimumMemoryGB
    }

    /// GPU when the memory allows it, otherwise CPU.
    public func backend(for spec: ModelSpec) -> ModelSpec.Backend {
        memoryGB >= spec.minimumMemoryGB ? spec.preferredBackend : .cpu
    }
}
