# 11. Risks and Technical Debt

## Risks

### R-1: Adaptive Algorithm Tuning

| Aspect | Detail |
|---|---|
| **Risk** | The Kazez staircase algorithm parameters may not converge to useful detection thresholds for all users. Over-narrowing could make training frustrating; over-widening could make it too easy. |
| **Probability** | Medium |
| **Impact** | High — the algorithm is the intellectual core of the app |
| **Mitigation** | Algorithm parameters are exposed for manual tuning during development (FR15). Convergence behavior validated through test cases. The narrowing/widening asymmetry (5% vs 9% step sizes) is designed to prevent boundary locking. |

### R-2: SoundFont Pitch Bend Limits

| Aspect | Detail |
|---|---|
| **Risk** | MIDI pitch bend is configured for ±2 semitones (±200 cents). Pitch matching challenges with initial offsets beyond this range would produce incorrect frequencies. |
| **Probability** | Low — current implementation uses ±20 cent offsets |
| **Impact** | Medium — audibly wrong pitch would confuse the user |
| **Mitigation** | `SoundFontPlaybackHandle.adjustFrequency()` clamps to ±200 cents from the base note. `PitchMatchingSession` generates challenges within ±20 cents. Future expansion would need to switch MIDI notes if exceeding the bend range. |

### R-3: SwiftData Maturity

| Aspect | Detail |
|---|---|
| **Risk** | SwiftData is relatively new (iOS 17). Schema migration tooling and edge-case handling may be less robust than Core Data. |
| **Probability** | Low — the data model is flat and simple |
| **Impact** | Medium — could affect data integrity on model changes |
| **Mitigation** | Data models are intentionally simple (flat records with primitive fields). No complex relationships. Migration needs are minimal. If needed, Core Data interop is available as a fallback. |

### R-4: iOS Version Dependency

| Aspect | Detail |
|---|---|
| **Risk** | Targeting iOS 26 only means the app requires the very latest OS version. Users on older devices cannot install it. |
| **Probability** | Certain (by design) |
| **Impact** | Low — Michael (primary user) runs latest iOS. No commercial distribution goals. |
| **Mitigation** | Accepted trade-off. Latest-only enables use of newest APIs without legacy workarounds. |

## Technical Debt

### TD-1: No iCloud Sync

Training data is device-local only. No mechanism to sync across devices or recover from device loss. Identified as a future enhancement in the PRD.

### TD-2: Profile Rebuild on Every Launch

The `PerceptualProfile` is rebuilt from all stored records on every app startup. Currently fast (milliseconds for thousands of records), but performance has not been profiled for very large datasets (tens of thousands of records over months of training). A caching strategy may become necessary.

### TD-3: ~~Data Export/Import Schema Evolution~~ (Resolved)

Resolved: CSV export now includes a format version metadata line (`# peach-export-format:1`). Import uses a protocol-based versioned parser dispatch (`CSVVersionedParser`), so new format versions are additive — a new conformance plus registration, no changes to existing parsers.

### TD-4: ~~Progress Chart Drill-Down~~ (Resolved)

Resolved: The chart UX was redesigned (Epic 41) with multi-granularity zones (session → day → month) rendered inline, replacing the interactive drill-down concept.

### TD-5: PlaybackHandle Relies on Explicit Cleanup

`SoundFontPlaybackHandle` has no `deinit`-based safety net. If a handle is dropped without `stop()`, the note plays until the audio engine shuts down. All current code paths stop handles explicitly, but a defensive `deinit` could catch future misuse.
