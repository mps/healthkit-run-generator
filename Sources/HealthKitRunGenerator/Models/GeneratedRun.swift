import Foundation

/// The complete output of a run generation — all data needed to create HealthKit objects.
public struct GeneratedRun: Sendable {
    /// The configuration used to generate this run
    public let configuration: RunConfiguration

    /// Aggregate metrics
    public let metrics: RunMetrics

    /// Time-series heart rate samples (timestamp offset in seconds, bpm)
    public let heartRateSamples: [(offset: TimeInterval, bpm: Double)]

    /// Time-series cadence samples (timestamp offset in seconds, steps per minute)
    public let cadenceSamples: [(offset: TimeInterval, spm: Double)]

    /// GPS route points for outdoor runs (timestamp offset, lat, lon, altitude in meters)
    /// Empty for indoor runs.
    public let routePoints: [(offset: TimeInterval, latitude: Double, longitude: Double, altitude: Double)]

    /// Start date of the workout
    public var startDate: Date { configuration.startDate }

    /// End date of the workout
    public var endDate: Date { configuration.startDate.addingTimeInterval(metrics.totalDuration) }

    public init(
        configuration: RunConfiguration,
        metrics: RunMetrics,
        heartRateSamples: [(offset: TimeInterval, bpm: Double)],
        cadenceSamples: [(offset: TimeInterval, spm: Double)],
        routePoints: [(offset: TimeInterval, latitude: Double, longitude: Double, altitude: Double)] = []
    ) {
        self.configuration = configuration
        self.metrics = metrics
        self.heartRateSamples = heartRateSamples
        self.cadenceSamples = cadenceSamples
        self.routePoints = routePoints
    }
}
