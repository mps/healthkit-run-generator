# HealthKit Run Generator — Project Plan

## Overview

A focused Swift Package that generates realistic HealthKit running workout data for iOS development and testing. Supports both **outdoor runs** and **indoor (treadmill) runs** with detailed per-sample metrics, route data, split analysis, and configurable runner profiles.

This project is inspired by [aminbenarieb/healthkit-data-generator](https://github.com/aminbenarieb/healthkit-data-generator) and adopts several of its architectural patterns — profile-based configuration, JSON import/export, and a registry-based sample creation pipeline — while narrowing the scope exclusively to running workouts with significantly deeper fidelity.

---

## Architecture Analysis of healthkit-data-generator

### Key Patterns Worth Adopting

| Pattern | How It's Used | Our Adaptation |
|---------|--------------|----------------|
| **Profile-based generation** | `HealthProfile` structs with preset personas (sporty, stressed, balanced) | `RunnerProfile` with running-specific personas (beginner 5K, marathon trainer, ultrarunner, treadmill user) |
| **Config-driven generation** | `SampleGenerationConfig` bundles profile + date range + pattern + overrides | `RunGenerationConfig` bundles runner profile + training plan + run type + terrain |
| **Registry-based sample creation** | `SampleCreatorRegistry` maps HK type strings → concrete creators | `RunSampleFactory` maps run sub-types → metric generators |
| **JSON import/export** | Full round-trip via `JsonTokenizer` / `JsonWriter` | Adopt same approach, extend schema for route + split data |
| **Generation patterns** | `GenerationPattern` enum (continuous, sparse, weekdays-only) | `TrainingPattern` with periodization (easy/tempo/interval/long-run/rest cycling) |
| **LLM integration** | `LLMManager` + `LLMProvider` protocol for natural-language config generation | Adopt same protocol; add running-specific prompt templates |

### Gaps We Fill

The original generator treats running as a generic workout: random 30-90 min duration, random 5-15 km distance, flat energy burn rate (`duration/60 * 10`). No pace variation, no splits, no heart rate zones, no route data, no cadence, no elevation, no indoor/outdoor distinction. That's the entire opportunity.

---

## Data Model

### Core Types

```swift
/// The atomic unit: a single run session
struct GeneratedRun {
    let type: RunType                    // .outdoor or .indoor
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval           // seconds
    let distance: Double                 // meters
    let totalEnergyBurned: Double        // kcal
    let averagePace: Double              // sec/km
    let splits: [Split]                  // per-km or per-mile splits
    let heartRateTimeSeries: [TimeSample<Int>]    // bpm over time
    let cadenceTimeSeries: [TimeSample<Int>]      // steps/min over time
    let powerTimeSeries: [TimeSample<Double>]?    // watts (optional, Apple Watch Ultra)
    let route: RunRoute?                 // CLLocation array (outdoor only)
    let elevationGain: Double?           // meters (outdoor only)
    let elevationLoss: Double?           // meters (outdoor only)
    let weather: WeatherConditions?      // temp, humidity, wind (outdoor only)
    let vo2MaxEstimate: Double?          // mL/kg/min
    let groundContactTime: TimeSample<Double>?    // ms
    let verticalOscillation: TimeSample<Double>?  // cm
    let strideLength: TimeSample<Double>?         // meters
    let workoutEvents: [RunWorkoutEvent] // pause/resume/lap/segment markers
}

enum RunType: String, Codable {
    case outdoor = "outdoor"
    case indoor = "indoor"      // treadmill
}

struct Split: Codable {
    let index: Int               // 1-based
    let distance: Double         // meters (typically 1000 or 1609.34)
    let duration: TimeInterval   // seconds
    let averagePace: Double      // sec/km
    let averageHeartRate: Int    // bpm
    let averageCadence: Int      // steps/min
    let elevationDelta: Double?  // meters (outdoor only)
}

struct TimeSample<T: Codable>: Codable {
    let timestamp: Date
    let value: T
}

struct RunRoute: Codable {
    let coordinates: [RoutePoint]
    let source: RouteSource      // .generated or .gpxTemplate
}

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double         // meters
    let timestamp: Date
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double            // m/s
    let course: Double           // degrees
}

enum RouteSource: String, Codable {
    case generated = "generated"       // algorithmically created
    case gpxTemplate = "gpx_template"  // based on a real GPX file
}

struct WeatherConditions: Codable {
    let temperature: Double      // celsius
    let humidity: Double         // 0-100%
    let windSpeed: Double        // m/s
    let windDirection: Double    // degrees
    let condition: WeatherCondition
}

enum WeatherCondition: String, Codable {
    case clear, cloudy, rain, snow, hot, cold, humid
}

struct RunWorkoutEvent: Codable {
    let type: RunEventType
    let timestamp: Date
    let metadata: [String: String]?
}

enum RunEventType: String, Codable {
    case pause, resume, lap, segment, marker
}
```

### Runner Profiles

```swift
struct RunnerProfile: Codable {
    let id: String
    let name: String
    let description: String
    
    // Fitness level
    let vo2Max: ClosedRange<Double>              // mL/kg/min
    let restingHeartRate: ClosedRange<Int>        // bpm
    let maxHeartRate: ClosedRange<Int>            // bpm
    let lactateThresholdPace: ClosedRange<Double> // sec/km
    
    // Running characteristics
    let weeklyMileage: ClosedRange<Double>        // km
    let preferredRunTypes: [RunSessionType]
    let typicalCadence: ClosedRange<Int>          // steps/min
    let typicalStrideLength: ClosedRange<Double>  // meters
    
    // Pacing behavior
    let easyPace: ClosedRange<Double>             // sec/km
    let tempoPace: ClosedRange<Double>            // sec/km
    let intervalPace: ClosedRange<Double>          // sec/km
    let longRunPace: ClosedRange<Double>           // sec/km
    let racePace: ClosedRange<Double>              // sec/km (goal race pace)
    
    // Heart rate zones (% of max HR)
    let hrZone1: ClosedRange<Double>              // recovery (50-60%)
    let hrZone2: ClosedRange<Double>              // easy (60-70%)
    let hrZone3: ClosedRange<Double>              // tempo (70-80%)
    let hrZone4: ClosedRange<Double>              // threshold (80-90%)
    let hrZone5: ClosedRange<Double>              // VO2max (90-100%)
    
    // Behavioral patterns
    let preferredTimeOfDay: ClosedRange<Int>      // hour (e.g. 6...8 for morning runner)
    let paceConsistency: Double                   // 0.0 (erratic) to 1.0 (metronome)
    let positiveSplitTendency: Double             // 0.0 (negative split) to 1.0 (always positive split)
    let warmupDuration: ClosedRange<TimeInterval> // seconds
    let cooldownDuration: ClosedRange<TimeInterval> // seconds
}
```

### Preset Runner Profiles

| Profile | VO2Max | Easy Pace | Weekly km | Cadence | Notes |
|---------|--------|-----------|-----------|---------|-------|
| `beginner5K` | 30-38 | 7:00-8:00/km | 15-25 | 155-165 | Walk breaks, high HR drift |
| `recreational` | 38-45 | 5:45-6:30/km | 25-40 | 165-175 | Consistent, some tempo work |
| `competitive10K` | 45-52 | 4:45-5:30/km | 40-65 | 170-180 | Structured training, intervals |
| `marathonTrainer` | 48-55 | 5:00-5:45/km | 55-90 | 172-182 | Long runs, periodization |
| `eliteRunner` | 55-75 | 4:00-4:30/km | 80-160 | 180-195 | Double days, high consistency |
| `treadmillUser` | 35-50 | 5:30-7:00/km | 15-35 | 165-178 | Indoor only, flat terrain |
| `trailRunner` | 42-55 | 5:30-7:00/km | 35-70 | 160-175 | Elevation, variable pace |
| `ultraRunner` | 45-58 | 5:30-6:30/km | 70-130 | 165-178 | Very long runs, walk/run |

### Run Session Types

```swift
enum RunSessionType: String, Codable {
    case easyRun           // conversational pace, zone 2
    case tempoRun          // comfortably hard, zone 3-4
    case intervalRun       // structured speed work (e.g. 6x800m)
    case longRun           // endurance, typically 1.5-3x weekday distance
    case recoveryRun       // very easy, short
    case progressionRun    // starts easy, finishes fast
    case fartlek           // unstructured speed play
    case hillRepeats       // repeated hill efforts
    case raceSimulation    // goal pace practice
    case treadmillRun      // indoor, controlled pace
    case walkRun           // intervals of walking and running (beginner)
}
```

---

## Generation Engine

### Training Plan Generator

Rather than random daily workouts, generate runs that follow realistic training periodization:

```swift
struct TrainingWeek: Codable {
    let weekNumber: Int
    let phase: TrainingPhase          // base, build, peak, taper, recovery
    let scheduledRuns: [ScheduledRun]
    let totalTargetDistance: Double    // km
    let totalTargetDuration: TimeInterval
}

enum TrainingPhase: String, Codable {
    case base       // building aerobic foundation
    case build      // increasing intensity
    case peak       // highest volume/intensity
    case taper      // reducing before race
    case recovery   // post-race or deload
}

struct ScheduledRun: Codable {
    let dayOfWeek: Int               // 1=Mon, 7=Sun
    let sessionType: RunSessionType
    let targetDistance: ClosedRange<Double>?   // km
    let targetDuration: ClosedRange<TimeInterval>?
    let targetPaceZone: Int?         // 1-5
    let intervals: IntervalStructure? // for interval/tempo sessions
}

struct IntervalStructure: Codable {
    let warmupDistance: Double        // km
    let repeats: Int
    let workDistance: Double          // km per repeat
    let workPace: ClosedRange<Double> // sec/km
    let restDuration: TimeInterval    // seconds between repeats
    let cooldownDistance: Double      // km
}
```

### Pace & Heart Rate Simulation

The core realism engine. For each second (or configurable interval) of a run:

1. **Base pace** from session type + runner profile
2. **Fatigue drift**: pace slows ~1-3% per 10 km based on `positiveSplitTendency`
3. **Terrain modifier**: elevation gain increases pace, descent decreases (outdoor)
4. **Cadence coupling**: pace changes correlate with cadence changes
5. **Heart rate lag**: HR responds to pace changes with 15-30 second delay
6. **Cardiac drift**: HR creeps up 5-10% over long runs at constant pace
7. **Interval transitions**: sharp pace/HR changes at work/rest boundaries
8. **Random variation**: Gaussian noise scaled by `paceConsistency`
9. **Weather impact**: heat/humidity increase HR and slow pace
10. **Warmup/cooldown**: gradual ramp-up and ramp-down periods

```swift
protocol PaceSimulator {
    func simulatePace(
        at timeOffset: TimeInterval,
        sessionType: RunSessionType,
        profile: RunnerProfile,
        terrain: TerrainProfile?,
        weather: WeatherConditions?,
        fatigueFactor: Double
    ) -> SimulatedInstant
}

struct SimulatedInstant {
    let pace: Double          // sec/km
    let heartRate: Int        // bpm
    let cadence: Int          // steps/min
    let power: Double?        // watts
    let strideLength: Double  // meters
    let elevation: Double?    // meters
    let coordinate: RoutePoint?
}
```

### Route Generation (Outdoor Only)

Two strategies:

1. **Algorithmic routes**: Generate realistic GPS coordinates using:
   - Starting point (configurable or random city coordinates)
   - Direction changes at realistic intervals (every 200-800m)
   - GPS jitter (±2-5m horizontal accuracy)
   - Elevation profiles from noise functions (Perlin or simplex)
   - Loop routes (start ≈ finish) for most runs
   - Out-and-back for longer runs

2. **GPX template routes**: Load real GPX files, replay coordinates at generated pace:
   - Scale route to match target distance
   - Interpolate timestamps to match pace profile
   - Ship a few bundled templates (flat city loop, hilly trail, track)

### Indoor Run Differences

Treadmill runs differ from outdoor:
- **No route data** (no CLLocation samples)
- **No elevation** data (or constant 0)
- **No GPS accuracy** fields
- **More consistent pace** (treadmill belt speed is constant per interval)
- **Slightly different cadence patterns** (belt assistance)
- **Distance from cadence/stride estimation** (less accurate)
- **Incline simulation** possible (treadmill grade as metadata)

---

## HealthKit Integration

### HKWorkout Construction

```swift
// Outdoor run
let workout = HKWorkout(
    activityType: .running,
    start: startDate,
    end: endDate,
    workoutEvents: events,
    totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
    totalDistance: HKQuantity(unit: .meter(), doubleValue: distance),
    metadata: [
        HKMetadataKeyIndoorWorkout: false,
        HKMetadataKeyWeatherTemperature: HKQuantity(unit: .degreeFahrenheit(), doubleValue: temp),
        HKMetadataKeyWeatherHumidity: HKQuantity(unit: .percent(), doubleValue: humidity),
        HKMetadataKeyElevationAscended: HKQuantity(unit: .meter(), doubleValue: elevGain)
    ]
)

// Indoor run
let workout = HKWorkout(
    activityType: .running,
    start: startDate,
    end: endDate,
    metadata: [
        HKMetadataKeyIndoorWorkout: true
    ]
)
```

### Associated Sample Types

| HealthKit Type | Unit | Indoor | Outdoor | Notes |
|----------------|------|--------|---------|-------|
| `HKWorkoutType` | — | ✅ | ✅ | The workout itself |
| `HKQuantityTypeIdentifierHeartRate` | count/min | ✅ | ✅ | Time series throughout run |
| `HKQuantityTypeIdentifierRunningSpeed` | m/s | ✅ | ✅ | Instantaneous speed samples |
| `HKQuantityTypeIdentifierStepCount` | count | ✅ | ✅ | Accumulated during run |
| `HKQuantityTypeIdentifierDistanceWalkingRunning` | m | ✅ | ✅ | Accumulated distance |
| `HKQuantityTypeIdentifierActiveEnergyBurned` | kcal | ✅ | ✅ | Energy during run |
| `HKQuantityTypeIdentifierBasalEnergyBurned` | kcal | ✅ | ✅ | Resting energy during run |
| `HKQuantityTypeIdentifierRunningStrideLength` | m | ✅ | ✅ | iOS 16+ |
| `HKQuantityTypeIdentifierRunningVerticalOscillation` | cm | ✅ | ✅ | iOS 16+ |
| `HKQuantityTypeIdentifierRunningGroundContactTime` | ms | ✅ | ✅ | iOS 16+ |
| `HKQuantityTypeIdentifierRunningPower` | W | ✅ | ✅ | iOS 16+, Apple Watch Ultra |
| `HKQuantityTypeIdentifierVO2Max` | mL/kg·min | ❌ | ✅ | Post-run estimate |
| `HKWorkoutRoute` | CLLocation[] | ❌ | ✅ | GPS route |
| `HKQuantityTypeIdentifierFlightsClimbed` | count | ❌ | ✅ | From elevation |

### Workout Builder API (Modern Approach)

Use `HKWorkoutBuilder` + `HKWorkoutRouteBuilder` for iOS 17+:

```swift
let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: nil)
try await builder.beginCollection(at: startDate)

// Add heart rate samples
try await builder.addSamples(heartRateSamples)

// Add distance samples  
try await builder.addSamples(distanceSamples)

// Add route
let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
try await routeBuilder.insertRouteData(locations)
try await routeBuilder.finishRoute(with: workout, metadata: nil)

// Add workout events (laps, pauses)
try await builder.addWorkoutEvents(events)

try await builder.endCollection(at: endDate)
let workout = try await builder.finishWorkout()
```

---

## Package Structure

```
Sources/
  HealthKitRunGenerator/
    Core/
      HealthKitRunGenerator.swift          // Public API entry point
      RunGenerationConfig.swift            // Configuration bundle
    Models/
      GeneratedRun.swift                   // Core run data model
      RunnerProfile.swift                  // Runner profile + presets
      RunSessionType.swift                 // Run type enum
      Split.swift                          // Per-split data
      TimeSample.swift                     // Generic time series sample
      RunRoute.swift                       // Route + coordinate models
      WeatherConditions.swift              // Weather data
      TrainingPlan.swift                   // Training week/phase models
      IntervalStructure.swift              // Interval workout structure
    Generation/
      PaceSimulator.swift                  // Pace/HR/cadence simulation engine
      FatigueModel.swift                   // Fatigue and cardiac drift
      RouteGenerator.swift                 // Algorithmic route generation
      GPXTemplateLoader.swift              // Load/replay GPX templates
      ElevationGenerator.swift             // Terrain elevation profiles
      WeatherGenerator.swift               // Random weather conditions
      IndoorRunGenerator.swift             // Treadmill-specific generation
      OutdoorRunGenerator.swift            // Outdoor-specific generation
      SplitCalculator.swift                // Compute splits from time series
      TrainingPlanGenerator.swift          // Weekly training schedule
    HealthKit/
      WorkoutBuilder.swift                 // HKWorkout construction
      SampleFactory.swift                  // HK sample creation
      RouteBuilder.swift                   // HKWorkoutRoute construction
      HealthKitPopulator.swift             // Save to HealthKit store
    Export/
      RunExporter.swift                    // Export to JSON
      GPXExporter.swift                    // Export to GPX format
    Import/
      RunImporter.swift                    // Import from JSON
      GPXImporter.swift                    // Import from GPX
    LLM/
      LLMRunProvider.swift                 // LLM provider protocol
      AppleFoundationModelRunProvider.swift // Apple FM integration
      RunPromptTemplates.swift             // Running-specific prompt templates
    Utilities/
      DateExtensions.swift
      MathHelpers.swift                    // Gaussian noise, interpolation
      UnitConversions.swift                // km↔mi, m/s↔min/km, etc.
      AppLogger.swift
    Resources/
      Routes/                              // Bundled GPX templates
        flat-city-5k.gpx
        hilly-trail-10k.gpx
        track-400m.gpx

Tests/
  HealthKitRunGeneratorTests/
    PaceSimulatorTests.swift
    RouteGeneratorTests.swift
    SplitCalculatorTests.swift
    IndoorRunGeneratorTests.swift
    OutdoorRunGeneratorTests.swift
    RunnerProfileTests.swift
    TrainingPlanTests.swift
    ExportImportRoundTripTests.swift
```

---

## Public API

```swift
import HealthKitRunGenerator
import HealthKit

let store = HKHealthStore()
let generator = HealthKitRunGenerator(healthStore: store)

// === Quick generation ===

// Generate a single outdoor easy run for a recreational runner
let run = generator.generateRun(
    type: .outdoor,
    sessionType: .easyRun,
    profile: .recreational,
    date: Date()
)

// Generate a treadmill interval session
let treadmillRun = generator.generateRun(
    type: .indoor,
    sessionType: .intervalRun,
    profile: .competitive10K,
    date: Date(),
    intervals: IntervalStructure(
        warmupDistance: 1600,
        repeats: 6,
        workDistance: 800,
        workPace: 210...220,  // ~3:30-3:40/km
        restDuration: 90,
        cooldownDistance: 1600
    )
)

// === Training plan generation ===

let config = RunGenerationConfig(
    profile: .marathonTrainer,
    dateRange: .lastDays(28),
    trainingPhase: .build,
    runsPerWeek: 5,
    longRunDay: .sunday,
    includeRoute: true,
    startLocation: CLLocationCoordinate2D(latitude: 33.749, longitude: -84.388) // Atlanta
)

let runs = generator.generateTrainingBlock(config: config)

// === Populate HealthKit ===

try await generator.populateHealthKit(with: runs)

// === Export ===

let json = try generator.exportToJSON(runs)
let gpx = try generator.exportToGPX(runs.first!)
```

---

## Implementation Phases

### Phase 1: Core Models & Basic Generation (MVP)
- [ ] Package.swift setup (swift-tools-version 6.0, iOS 17+, macOS 14+)
- [ ] All data models (`GeneratedRun`, `RunnerProfile`, `Split`, `TimeSample`, etc.)
- [ ] 3 runner profile presets (beginner, recreational, marathon trainer)
- [ ] Basic `PaceSimulator` with fatigue drift and random variation
- [ ] Simple outdoor run generation (no route, constant-ish terrain)
- [ ] Simple indoor run generation
- [ ] Split calculator
- [ ] JSON export/import
- [ ] Unit tests for core generation

### Phase 2: Realism & Route Data
- [ ] Full pace simulation engine (HR lag, cardiac drift, warmup/cooldown)
- [ ] Algorithmic route generation with GPS jitter
- [ ] Elevation profiles (Perlin noise)
- [ ] Weather conditions generation and impact modeling
- [ ] All 8 runner profile presets
- [ ] Interval/tempo/fartlek session generation
- [ ] GPX template loading and replay
- [ ] Running dynamics (ground contact time, vertical oscillation, stride length, power)

### Phase 3: HealthKit Integration
- [ ] `HKWorkoutBuilder` integration
- [ ] `HKWorkoutRouteBuilder` for GPS data
- [ ] All associated HK sample types (HR, distance, cadence, running dynamics)
- [ ] Workout events (pause/resume/lap)
- [ ] Metadata (indoor flag, weather, elevation ascended)
- [ ] Full HealthKit population pipeline
- [ ] Store cleanup utility

### Phase 4: Training Plans & LLM
- [ ] Training plan generator (base → build → peak → taper)
- [ ] Weekly schedule generation with run type distribution
- [ ] Progressive overload modeling
- [ ] LLM provider protocol and Apple Foundation Model integration
- [ ] Running-specific prompt templates
- [ ] GPX export
- [ ] Demo SwiftUI app

---

## Key Design Decisions

1. **Swift 6 strict concurrency** — All public APIs are `Sendable`; async/await for HealthKit operations.
2. **Value types everywhere** — Models are structs, not classes. Codable by default.
3. **Protocol-driven generation** — `PaceSimulator`, `RouteGenerator`, `WeatherProvider` are protocols for testability and extensibility.
4. **No external dependencies** except `swift-log` — Keep the dependency graph minimal.
5. **Seconds-resolution time series** — Generate data points every 1-5 seconds for realism, then downsample for HealthKit (which typically stores every 5-10 seconds).
6. **Reproducible generation** — Random seed support for deterministic output in tests.
7. **Metric-first, imperial-friendly** — Internal calculations in meters/seconds; convenience APIs for miles/min-per-mile.

---

## References

- [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [HKWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder)
- [HKWorkoutRouteBuilder](https://developer.apple.com/documentation/healthkit/hkworkoutroutebuilder)
- [Running Dynamics (iOS 16+)](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier)
- [aminbenarieb/healthkit-data-generator](https://github.com/aminbenarieb/healthkit-data-generator)
- [Jack Daniels' Running Formula](https://en.wikipedia.org/wiki/Jack_Daniels_(coach)) — VDOT tables for pace zone calculations
