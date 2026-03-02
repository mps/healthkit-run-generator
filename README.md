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

## Batch Generation

Generate multiple runs at once with deterministic seeds, configuration profiles, and filtering.

```swift
let batch = BatchRunGenerator()

// Generate 100 runs with seed range
let runs = batch.generate(
    seedRange: 1...100,
    profile: .easyRun,
    fitnessLevel: .intermediate,
    distance: .miles(5)
)

// Generate using a configuration profile (e.g., threshold week)
let weekRuns = batch.generate(
    count: 1,
    configProfile: .thresholdWeek,
    fitnessLevel: .advanced,
    weeklyMileage: 40
)

// Filter results
let filter = BatchRunGenerator.FilterOptions(
    minDistanceMiles: 3.0,
    maxDistanceMiles: 8.0,
    profiles: [.tempoRun, .intervalRun]
)
let filtered = batch.generate(
    seedRange: 1...50,
    profile: .tempoRun,
    fitnessLevel: .advanced,
    distance: .miles(5),
    filter: filter
)

// Export to JSON
if let jsonData = BatchRunGenerator.toJSONData(runs) {
    try jsonData.write(to: URL(fileURLWithPath: "runs.json"))
}
```

### Configuration Profiles

| Profile | Runs/Week | Focus |
|---------|-----------|-------|
| `easyWeek` | 5 | All easy runs + long run |
| `thresholdWeek` | 6 | Tempo emphasis + long run |
| `longRunFocused` | 5 | 50% mileage in long run |
| `speedWork` | 6 | Interval sessions + long run |
| `recoveryWeek` | 4 | All easy, reduced volume |
| `balanced` | 6 | Mix of easy, tempo, intervals, long |

### JSON Export Format

```json
[
  {
    "seed": 1,
    "profile": "easyRun",
    "fitnessLevel": "intermediate",
    "runType": "outdoor",
    "distance_miles": 5.0,
    "distance_meters": 8046.72,
    "duration_seconds": 2835.4,
    "average_pace_per_mile": 567.08,
    "average_heart_rate": 142.3,
    "max_heart_rate": 161.0,
    "average_cadence": 170.0,
    "total_calories": 485.2,
    "elevation_gain_meters": 12.5,
    "elevation_loss_meters": 11.8,
    "start_date": "2026-03-01T12:00:00Z",
    "end_date": "2026-03-01T12:47:15Z",
    "splits": [
      {
        "index": 0,
        "distance_meters": 1609.344,
        "duration_seconds": 558.2,
        "pace_per_mile": 558.2,
        "average_heart_rate": 138.0,
        "average_cadence": 169.0,
        "elevation_gain": 2.5,
        "elevation_loss": 1.8,
        "calories": 97.0
      }
    ]
  }
]
```

## Training Plans

Generate realistic 4-week training cycles with periodization, rest days, and varied run types.

```swift
let planner = TrainingPlanGenerator()

// Generate a half-marathon training block
let plan = planner.generate(
    fitnessLevel: .intermediate,
    goalDistance: .halfMarathon,
    baseSeed: 42
)

// Inspect the plan
print(plan.totalMileage)           // Total miles across 4 weeks
print(plan.weeklyMileage)          // [30.0, 32.4, 34.5, 22.5]
print(plan.intensityDistribution)  // (easy: 0.55, tempo: 0.15, interval: 0.10, longRun: 0.20)
print(plan.restDays.count)         // 8

// Iterate by week
for week in 0..<4 {
    let weekRuns = plan.runsForWeek(week)
    for scheduled in weekRuns {
        print("Day \(scheduled.dayIndex + 1): \(scheduled.purpose)")
        print("  \(scheduled.run.metrics)")
    }
}
```

### Goal Distances

| Goal | Beginner | Intermediate | Advanced | Elite |
|------|----------|-------------|----------|-------|
| 5K | 12 mi/wk, 4 runs | 20 mi/wk, 5 runs | 30 mi/wk, 5 runs | 40 mi/wk, 6 runs |
| 10K | 15 mi/wk, 4 runs | 25 mi/wk, 5 runs | 35 mi/wk, 5 runs | 50 mi/wk, 6 runs |
| Half Marathon | 20 mi/wk, 4 runs | 30 mi/wk, 5 runs | 45 mi/wk, 5 runs | 60 mi/wk, 6 runs |
| Marathon | 25 mi/wk, 4 runs | 35 mi/wk, 5 runs | 55 mi/wk, 5 runs | 75 mi/wk, 6 runs |

### Sample 4-Week Plan (Intermediate Half Marathon)

```
Training Plan: Half Marathon (intermediate)
Total Mileage: 119.1 miles over 4 weeks

Week 1 — 30.0 miles
  Day 1: Easy run — 2.7 mi @ 10:12/mi
  Day 2: Tempo run — 2.9 mi @ 8:45/mi
  Day 3: Easy recovery — 2.4 mi @ 10:30/mi
  Day 4: Easy run — 3.0 mi @ 10:15/mi
  Day 5: Pre-long-run shakeout — 2.1 mi @ 10:20/mi
  Day 7: Long run — 10.5 mi @ 9:55/mi

Week 2 — 32.4 miles (build)
  Day 8:  Easy run — 2.9 mi @ 10:08/mi
  Day 9:  Tempo run — 3.1 mi @ 8:40/mi
  Day 10: Easy recovery — 2.6 mi @ 10:25/mi
  Day 11: Easy run — 3.2 mi @ 10:10/mi
  Day 12: Pre-long-run shakeout — 2.3 mi @ 10:18/mi
  Day 14: Long run — 11.3 mi @ 9:50/mi

Week 3 — 34.5 miles (peak)
  Day 15: Easy run — 3.1 mi @ 10:05/mi
  Day 16: Tempo run — 3.3 mi @ 8:35/mi
  Day 17: Easy recovery — 2.8 mi @ 10:22/mi
  Day 18: Speed work — 3.1 mi @ 9:00/mi
  Day 19: Pre-long-run shakeout — 2.4 mi @ 10:15/mi
  Day 21: Peak long run — 12.1 mi @ 9:48/mi

Week 4 — 22.5 miles (recovery)
  Day 22: Easy recovery — 2.0 mi @ 10:30/mi
  Day 23: Easy recovery — 2.2 mi @ 10:28/mi
  Day 24: Easy recovery — 1.8 mi @ 10:35/mi
  Day 25: Easy recovery — 2.3 mi @ 10:25/mi
  Day 26: Easy recovery — 1.6 mi @ 10:32/mi
  Day 28: Recovery long run — 7.9 mi @ 10:05/mi
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

## API Reference

### Core Generators

| Class | Description |
|-------|-------------|
| `OutdoorRunGenerator` | Generates outdoor runs with GPS routes and elevation |
| `IndoorRunGenerator` | Generates treadmill runs with incline support |
| `BatchRunGenerator` | Generates N runs with seed ranges and filtering |
| `TrainingPlanGenerator` | Creates 4-week periodized training cycles |

### BatchRunGenerator

```swift
// Seed range generation
func generate(seedRange:profile:fitnessLevel:distance:runType:terrain:startDate:filter:) -> [GeneratedRun]

// Profile-based generation
func generate(count:configProfile:fitnessLevel:weeklyMileage:runType:terrain:baseSeed:startDate:filter:) -> [GeneratedRun]

// JSON export
static func toJSON(_ runs: [GeneratedRun]) -> [[String: Any]]
static func toJSONData(_ runs: [GeneratedRun], prettyPrinted: Bool) -> Data?
```

### TrainingPlanGenerator

```swift
func generate(fitnessLevel:goalDistance:startDate:baseSeed:runType:terrain:) -> TrainingPlan
```

### TrainingPlan Properties

| Property | Type | Description |
|----------|------|-------------|
| `runs` | `[ScheduledRun]` | All scheduled runs |
| `totalMileage` | `Double` | Total miles across 4 weeks |
| `weeklyMileage` | `[Double]` | Per-week mileage array |
| `intensityDistribution` | Named tuple | Easy/tempo/interval/long run percentages |
| `restDays` | `[Int]` | Day indices with no run |
| `runsForWeek(_:)` | `[ScheduledRun]` | Runs for a specific week (0-indexed) |

### Models

| Type | Description |
|------|-------------|
| `ConfigurationProfile` | Week-level presets: `easyWeek`, `thresholdWeek`, `longRunFocused`, `speedWork`, `recoveryWeek`, `balanced` |
| `GoalDistance` | Race targets: `fiveK`, `tenK`, `halfMarathon`, `marathon` |
| `ScheduledRun` | A run within a training plan with day index and purpose |
| `FilterOptions` | Distance, pace, type, and profile filters for batch generation |

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- HealthKit entitlement

## License

MIT
