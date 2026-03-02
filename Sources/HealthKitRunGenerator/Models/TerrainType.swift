import Foundation

/// Terrain profile for outdoor runs. Affects pace variation and elevation generation.
public enum TerrainType: String, Sendable, Codable, CaseIterable {
    case flat
    case rolling
    case hilly

    /// Maximum elevation gain per mile in meters
    public var maxElevationGainPerMile: Double {
        switch self {
        case .flat:    return 5.0
        case .rolling: return 30.0
        case .hilly:   return 80.0
        }
    }

    /// Pace penalty factor — multiplier applied to base pace on uphills
    public var uphillPaceFactor: Double {
        switch self {
        case .flat:    return 1.0
        case .rolling: return 1.08
        case .hilly:   return 1.18
        }
    }
}
