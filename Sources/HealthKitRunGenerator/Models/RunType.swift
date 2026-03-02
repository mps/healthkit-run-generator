import Foundation

/// The environment in which a run takes place.
public enum RunType: String, Sendable, Codable, CaseIterable {
    case outdoor
    case indoor
}
