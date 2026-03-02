# HealthKit Run Generator — Implementation Plan

## Overview

A focused Swift Package for generating realistic HealthKit running workout data — both outdoor and indoor (treadmill) runs. Produces complete `HKWorkout` objects with route data, heart rate samples, split metrics, and cadence data that mirror real-world running patterns.

Inspired by [aminbenarieb/healthkit-data-generator](https://github.com/aminbenarieb/healthkit-data-generator) but purpose-built for running workouts with physiologically accurate data generation.

## Architecture

```
Sources/HealthKitRunGenerator/
├── Models/              # Core data types and run configurations
├── Generators/          # Outdoor and indoor run generators  
├── Metrics/             # Heart rate, pace, cadence simulation
├── Route/               # GPS route generation (outdoor only)
└── Extensions/          # HealthKit convenience extensions
Tests/HealthKitRunGeneratorTests/
├── ModelTests/
├── OutdoorRunTests/
├── IndoorRunTests/
└── MetricsTests/
```

## Phases

### Phase 1: Core Run Data Model and Types
- `RunConfiguration` — distance, duration, type (outdoor/indoor), fitness level, terrain
- `RunProfile` — presets: easy, tempo, interval, long run, race
- `RunMetrics` — pace, heart rate, cadence, elevation, calories
- `SplitData` — per-mile/km split metrics
- `FitnessLevel` — beginner, intermediate, advanced, elite (drives physiological ranges)
- `RunType` enum — outdoor, indoor
- `TerrainType` — flat, hilly, mixed (outdoor only)

### Phase 2: Outdoor Run Generator
- GPS route generation with realistic coordinate progression
- Elevation profile generation (flat, rolling hills, hilly)
- Pace variation modeling (natural drift, fatigue, terrain effects)
- Heart rate curve: warmup → steady state → drift → cooldown
- Cadence modeling correlated with pace
- `HKWorkout` creation with `HKWorkoutRoute` and associated samples
- Split generation (per mile/km)
- Weather-influenced pace adjustments (optional config)

### Phase 3: Indoor Run Generator
- Treadmill-specific data (no GPS route)
- Steady-pace modeling with realistic micro-variations
- Heart rate response to treadmill speed/incline changes
- Incline profile support (flat, progressive, interval)
- Cadence tied to belt speed
- `HKWorkout` creation without route data
- Calorie estimation adjusted for treadmill (no wind resistance factor)

### Phase 4: Test Suite
- Unit tests for all model types and configurations
- Metric range validation (physiologically plausible values)
- Outdoor run: route continuity, elevation consistency, pace/HR correlation
- Indoor run: no route data present, incline effects on metrics
- Split accuracy tests (total distance = sum of splits)
- Edge cases: very short runs, ultra distances, zero elevation
- Profile preset validation

## Key Metrics & Ranges

| Metric | Beginner | Intermediate | Advanced | Elite |
|--------|----------|-------------|----------|-------|
| Easy pace (min/mi) | 12:00-14:00 | 9:30-11:00 | 7:30-9:00 | 6:00-7:00 |
| Max HR (bpm) | 180-200 | 175-195 | 170-190 | 165-185 |
| Resting HR (bpm) | 70-80 | 60-70 | 50-60 | 40-50 |
| Cadence (spm) | 150-165 | 165-175 | 175-185 | 180-195 |
| VO2max proxy | 25-35 | 35-45 | 45-55 | 55-70 |

## Run Profile Presets

- **Easy Run**: 60-70% max HR, conversational pace, 30-60 min
- **Tempo Run**: 80-85% max HR, comfortably hard, 20-40 min
- **Interval**: Alternating 90-95% / 60% max HR, 30-45 min total
- **Long Run**: 65-75% max HR, progressive fatigue, 60-150 min
- **Race (5K)**: 85-95% max HR, negative split tendency, 15-35 min
- **Race (Half Marathon)**: 80-88% max HR, even effort, 75-150 min
- **Race (Marathon)**: 75-85% max HR, careful pacing, 150-300 min

## Design Decisions

1. **Swift 6.0 + Sendable** — modern concurrency support throughout
2. **No external dependencies** — only HealthKit and CoreLocation frameworks
3. **Protocol-oriented generators** — `RunGenerator` protocol with outdoor/indoor conformers
4. **Deterministic option** — seed-based randomness for reproducible test data
5. **iOS 17+ / macOS 14+** — leverages latest HealthKit APIs
