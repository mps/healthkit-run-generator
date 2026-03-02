import Foundation

/// Complete configuration for generating a run workout.
public struct RunConfiguration: Sendable {
    /// Run profile preset (easy, tempo, interval, etc.)
    public let profile: RunProfile

    /// Runner fitness level
    public let fitnessLevel: FitnessLevel

    /// Target distance
    public let distance: Distance

    /// Run environment (outdoor or indoor)
    public let runType: RunType

    /// Terrain for outdoor runs (ignored for indoor)
    public let terrain: TerrainType

    /// Incline profile for indoor runs (ignored for outdoor)
    public let inclineProfile: InclineProfile

    /// Start date/time for the workout
    public let startDate: Date

    /// Optional seed for deterministic generation
    public let seed: UInt64?

    /// Starting coordinate for outdoor runs (latitude, longitude)
    public let startCoordinate: (latitude: Double, longitude: Double)?

    public init(
        profile: RunProfile,
        fitnessLevel: FitnessLevel,
        distance: Distance,
        runType: RunType = .outdoor,
        terrain: TerrainType = .flat,
        inclineProfile: InclineProfile = .flat,
        startDate: Date = Date(),
        seed: UInt64? = nil,
        startCoordinate: (latitude: Double, longitude: Double)? = nil
    ) {
        self.profile = profile
        self.fitnessLevel = fitnessLevel
        self.distance = distance
        self.runType = runType
        self.terrain = terrain
        self.inclineProfile = inclineProfile
        self.startDate = startDate
        self.seed = seed
        self.startCoordinate = startCoordinate
    }
}
