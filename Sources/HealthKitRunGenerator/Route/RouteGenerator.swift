import Foundation

/// Generates realistic GPS route points for outdoor runs.
struct RouteGenerator {
    /// Default start coordinate (Atlanta, GA — near Chick-fil-A HQ)
    static let defaultStart = (latitude: 33.7490, longitude: -84.3880)

    /// Generate route points along a roughly linear path with realistic variation.
    /// - Parameters:
    ///   - distance: Total distance in meters
    ///   - duration: Total duration in seconds
    ///   - terrain: Terrain type for elevation profile
    ///   - startCoordinate: Starting lat/lon
    ///   - rng: Random number generator
    static func generate(
        distance: Double,
        duration: TimeInterval,
        terrain: TerrainType,
        startCoordinate: (latitude: Double, longitude: Double),
        rng: inout RunRNG
    ) -> [(offset: TimeInterval, latitude: Double, longitude: Double, altitude: Double)] {
        let sampleInterval: TimeInterval = 3.0 // GPS sample every 3 seconds
        let pointCount = Int(duration / sampleInterval) + 1

        // Meters per degree at this latitude
        let metersPerDegreeLat = 111_132.0
        let metersPerDegreeLon = 111_132.0 * cos(startCoordinate.latitude * .pi / 180)

        // Random initial bearing (0-360 degrees)
        let bearing = rng.double(in: 0...360) * .pi / 180

        // Speed in meters per second
        let avgSpeed = distance / duration

        // Generate elevation profile
        let baseAltitude = rng.double(in: 200...400) // meters above sea level
        let elevations = generateElevationProfile(
            pointCount: pointCount,
            terrain: terrain,
            baseAltitude: baseAltitude,
            rng: &rng
        )

        var points: [(TimeInterval, Double, Double, Double)] = []
        var currentLat = startCoordinate.latitude
        var currentLon = startCoordinate.longitude
        var currentBearing = bearing

        for i in 0..<pointCount {
            let offset = Double(i) * sampleInterval
            if offset > duration { break }

            // Add gentle bearing changes (simulating road curves)
            if i > 0 {
                let bearingChange = rng.gaussian(mean: 0, stddev: 0.02) // ~1 degree std
                currentBearing += bearingChange

                // Occasional larger turns (intersections, trail bends)
                if rng.double(in: 0...1) < 0.02 {
                    currentBearing += rng.double(in: -0.5...0.5) // up to ~30 degrees
                }
            }

            let altitude = i < elevations.count ? elevations[i] : baseAltitude

            points.append((offset, currentLat, currentLon, altitude))

            // Move position
            let speedVariation = rng.gaussian(mean: 1.0, stddev: 0.05)
            let stepDistance = avgSpeed * sampleInterval * max(0.8, min(1.2, speedVariation))
            let dLat = stepDistance * cos(currentBearing) / metersPerDegreeLat
            let dLon = stepDistance * sin(currentBearing) / metersPerDegreeLon

            currentLat += dLat
            currentLon += dLon
        }

        return points
    }

    /// Generate an elevation profile matching the terrain type.
    private static func generateElevationProfile(
        pointCount: Int,
        terrain: TerrainType,
        baseAltitude: Double,
        rng: inout RunRNG
    ) -> [Double] {
        guard pointCount > 0 else { return [] }

        var elevations: [Double] = []
        var currentAlt = baseAltitude

        // Determine hill characteristics from terrain
        let maxChange: Double
        let frequency: Double

        switch terrain {
        case .flat:
            maxChange = 0.3  // meters per sample
            frequency = 0.0
        case .rolling:
            maxChange = 1.2
            frequency = 0.15
        case .hilly:
            maxChange = 2.5
            frequency = 0.25
        }

        for i in 0..<pointCount {
            if terrain == .flat {
                // Very minor undulation
                currentAlt += rng.gaussian(mean: 0, stddev: maxChange)
            } else {
                // Sinusoidal hills with noise
                let hillWave = sin(Double(i) * frequency) * terrain.maxElevationGainPerMile * 0.3
                let noise = rng.gaussian(mean: 0, stddev: maxChange * 0.3)
                currentAlt = baseAltitude + hillWave + noise
            }

            // Clamp altitude to reasonable range
            currentAlt = max(0, min(5000, currentAlt))
            elevations.append(currentAlt)
        }

        return elevations
    }
}
