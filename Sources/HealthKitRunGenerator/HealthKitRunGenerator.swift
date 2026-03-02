// HealthKitRunGenerator
// A Swift Package for generating realistic HealthKit running workout data.

/// Re-export all public types for convenient access.
///
/// Usage:
/// ```swift
/// import HealthKitRunGenerator
///
/// let config = RunConfiguration(
///     profile: .easyRun,
///     fitnessLevel: .intermediate,
///     distance: .miles(5)
/// )
/// let generator = OutdoorRunGenerator()
/// let run = generator.generate(config: config)
/// ```
public enum HealthKitRunGeneratorVersion {
    public static let version = "0.1.0"
}
