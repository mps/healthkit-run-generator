import Foundation

/// Protocol for run data generators.
public protocol RunGenerator: Sendable {
    /// Generate a complete run from the given configuration.
    func generate(config: RunConfiguration) -> GeneratedRun
}
