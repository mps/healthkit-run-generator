// HealthKit extensions for converting GeneratedRun to HKWorkout and associated samples.
// These require HealthKit framework availability (iOS/watchOS only).

#if canImport(HealthKit)
import HealthKit
import CoreLocation

extension GeneratedRun {
    /// Create an HKWorkout from this generated run.
    public func makeWorkout() -> HKWorkout {
        let activityType: HKWorkoutActivityType = configuration.runType == .outdoor
            ? .running : .running

        let workout = HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            duration: metrics.totalDuration,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: metrics.totalCalories),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: metrics.totalDistance),
            metadata: [
                HKMetadataKeyIndoorWorkout: configuration.runType == .indoor
            ]
        )
        return workout
    }

    /// Create heart rate samples as HKQuantitySample array.
    public func makeHeartRateSamples() -> [HKQuantitySample] {
        let unit = HKUnit.count().unitDivided(by: .minute())
        let type = HKQuantityType(.heartRate)

        return heartRateSamples.map { sample in
            let date = startDate.addingTimeInterval(sample.offset)
            return HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: sample.bpm),
                start: date,
                end: date
            )
        }
    }

    /// Create cadence samples as HKQuantitySample array.
    public func makeCadenceSamples() -> [HKQuantitySample] {
        let unit = HKUnit.count().unitDivided(by: .minute())
        let type = HKQuantityType(.runningStepCount)

        return cadenceSamples.map { sample in
            let date = startDate.addingTimeInterval(sample.offset)
            return HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: sample.spm),
                start: date,
                end: date
            )
        }
    }

    /// Create CLLocation array for route builder (outdoor runs only).
    public func makeRouteLocations() -> [CLLocation] {
        routePoints.map { point in
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: point.latitude,
                    longitude: point.longitude
                ),
                altitude: point.altitude,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                timestamp: startDate.addingTimeInterval(point.offset)
            )
        }
    }
}
#endif
