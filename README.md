# HealthKit Run Generator

A Swift Package for generating realistic HealthKit running workout data — outdoor runs with GPS routes and indoor treadmill runs with accurate physiological metrics.

## Features

- **Outdoor Runs**: GPS route generation, elevation profiles, terrain-aware pacing
- **Indoor Runs**: Treadmill simulation with incline support, no GPS data
- **Physiological Accuracy**: Heart rate curves, cadence correlation, fatigue modeling
- **Run Profiles**: Easy, tempo, interval, long run, and race presets
- **Fitness Levels**: Beginner → Elite with calibrated metric ranges
- **Deterministic Mode**: Seed-based generation for reproducible test data

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/mps/healthkit-run-generator", from: "0.1.0")
]
```

## Quick Start

```swift
import HealthKitRunGenerator
import HealthKit

let healthStore = HKHealthStore()
let generator = OutdoorRunGenerator()

// Generate an easy outdoor run
let config = RunConfiguration(
    profile: .easyRun,
    fitnessLevel: .intermediate,
    distance: .miles(5),
    terrain: .rolling
)

let workout = try await generator.generate(config: config)
// workout contains HKWorkout + route + heart rate + cadence samples
```

### Indoor Run

```swift
let treadmill = IndoorRunGenerator()

let config = RunConfiguration(
    profile: .tempoRun,
    fitnessLevel: .advanced,
    distance: .miles(4),
    inclineProfile: .progressive(maxGrade: 3.0)
)

let workout = try await treadmill.generate(config: config)
```

### Presets

```swift
// Quick generation with sensible defaults
let easyRun = try await OutdoorRunGenerator.easyRun(miles: 3, level: .beginner)
let tempoRun = try await OutdoorRunGenerator.tempoRun(miles: 5, level: .intermediate)
let longRun = try await OutdoorRunGenerator.longRun(miles: 13, level: .advanced)
```

## Supported Metrics

| Metric | Outdoor | Indoor |
|--------|---------|--------|
| Distance | ✅ | ✅ |
| Duration | ✅ | ✅ |
| Heart Rate | ✅ | ✅ |
| Cadence | ✅ | ✅ |
| Pace (per split) | ✅ | ✅ |
| Calories | ✅ | ✅ |
| GPS Route | ✅ | ❌ |
| Elevation | ✅ | ❌ |
| Incline | ❌ | ✅ |

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- HealthKit entitlement

## License

MIT
