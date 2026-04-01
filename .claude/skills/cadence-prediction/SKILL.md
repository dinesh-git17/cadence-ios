---
name: cadence-prediction
description: >
  Implement the Cadence cycle prediction engine correctly. Use this skill
  whenever implementing, modifying, or debugging any prediction logic in the
  Cadence iOS app — including cycle length prediction, phase calculation,
  fertile window, cold-start seeding, CycleRecord derivation, edge case
  handling (14-day spotting rule, 60-day confidence flag, confidence tiers),
  or unit tests for prediction logic. Always read this skill before writing
  any prediction-related Swift code. Do not guess at algorithm details or
  edge case thresholds — they are fully specified here.
---

# Cadence Prediction Engine

This skill teaches Claude Code exactly how to implement the Cadence cycle
prediction engine. Read it fully before writing a single line of prediction
code. All algorithm decisions, thresholds, and edge case rules are specified
here — do not invent alternatives without explicit instruction.

## Quick Reference

| File | Purpose |
|---|---|
| `SKILL.md` (this file) | Algorithm spec, data models, design decisions, edge cases |
| `references/swift-implementation.md` | Complete `PredictionEngine.swift` source |
| `references/unit-tests.md` | Complete `PredictionEngineTests.swift` XCTest suite |

**Read `references/swift-implementation.md` before writing any Swift.**  
**Read `references/unit-tests.md` before writing any tests.**

---

## 1. Why Weighted Average — Not Simple Average

A simple (unweighted) mean treats all historical cycles equally. This is wrong
for two reasons:

1. **Trend capture.** If a user's cycle has been shortening over 6 months
   (e.g., [30, 28, 26, 24, 22]), a simple average gives 26 days. The weighted
   average gives 25 days — correctly tracking the trend toward her actual next
   period.

2. **Outlier decay.** An anomalous long cycle 18 months ago (illness, travel,
   stress) should have much less influence than last month's cycle. Weighting
   by recency naturally accomplishes this.

Simple average is insufficient for irregular cycles — it consistently
mispredicts in exactly the cases where prediction matters most.

---

## 2. Weighting Function — Linear Position Weights

**Algorithm:** Assign each completed cycle an integer weight equal to its
chronological position, where the most recent completed cycle has the highest
weight.

Given `n` completed cycles sorted oldest-first:

```
cycle[0] (oldest)  → weight 1
cycle[1]           → weight 2
...
cycle[n-1] (newest) → weight n
```

```
weightedAverage = Σ(weight[i] × value[i]) / Σ(weight[i])
                = Σ((i+1) × value[i]) / (n × (n+1) / 2)
```

**Worked example** — 5 cycles [26, 30, 27, 29, 28] (oldest→newest):
```
weights     = [1, 2, 3, 4, 5]
weightedSum = (1×26) + (2×30) + (3×27) + (4×29) + (5×28) = 423
totalWeight = 15
average     = 423 / 15 = 28.2 → 28 days  ✓
```

**Trend example** — shortening cycle [30, 28, 26, 24, 22]:
```
weightedAvg = 24.67 → 25 days    (correctly tracks trend)
simpleAvg   = 26.00 → 26 days    (lags behind reality)
```

**Why not exponential decay?** For typical cycle data (3–24 cycles), linear
weights are sufficient and produce stable results. Exponential decay
(e.g., λ=0.7) over-penalises cycles from 3–4 months ago when data is sparse,
which is most of the time. Linear weighting is also transparent and easy to
unit-test. Reconsider for v2 if/when ML is added.

**No cap on history.** Use all completed cycles. With linear weights, a cycle
from 24 months ago (weight 1 of ~24) contributes ≈4% to the average — low
but nonzero, which is correct.

---

## 3. Data Models

All models should be in `Models/Cycle/`. Do not scatter them.

```swift
// MARK: - CycleRecord
/// A single completed menstrual cycle derived from logged data.
/// `cycleLength` is nil for the current (ongoing) cycle — we don't know
/// when it ends yet.
struct CycleRecord: Equatable {
    let startDate: Date          // Normalised to start-of-day
    let periodDuration: Int      // Calendar days, first flow day through last
    let cycleLength: Int?        // Days from this start to next start; nil if ongoing
}

// MARK: - CyclePhase
enum CyclePhase: String, CaseIterable {
    case menstrual
    case follicular
    case ovulation
    case luteal
}

// MARK: - PhaseInterval
struct PhaseInterval: Equatable {
    let phase: CyclePhase
    let startDate: Date          // Inclusive
    let endDate: Date            // Exclusive — first day of NEXT phase
    
    var dateInterval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }
    
    /// True when the phase has zero calendar duration.
    /// Short cycles can produce a zero-duration follicular phase; skip
    /// rendering these but keep them in the model.
    var isEmpty: Bool { startDate >= endDate }
}

// MARK: - PredictionConfidence
enum PredictionConfidence {
    case seed    // 0 completed cycles — onboarding data only. Label: "Estimated"
    case low     // 1–2 completed cycles — show low-confidence indicator
    case high    // 3+ completed cycles — full display, no indicator
    
    var requiresLabel: Bool { self != .high }
    var localizedLabel: String {
        switch self {
        case .seed: return "Estimated"
        case .low:  return "Low confidence"
        case .high: return ""
        }
    }
}

// MARK: - CyclePrediction
struct CyclePrediction {
    let nextPeriodStart: Date
    let phases: [PhaseInterval]       // Always 4 entries; some may be .isEmpty
    let fertileWindow: DateInterval
    let confidence: PredictionConfidence
    let isLate: Bool                  // Predicted date has passed; no period logged
    let isLowConfidenceDueToGap: Bool // 60+ days since last period logged
}
```

---

## 4. Phase Calculation Spec

**Core principle:** Luteal phase length is relatively constant at ~14 days.
All other phase boundaries are derived from this anchor. This is the
medically accepted approach and explains why ovulation day shifts with cycle
length.

### Formulas (all day numbers are 1-indexed from cycle start)

```
ovulationDay      = max(periodDuration + 1, cycleLength - 14)
ovulationDayEnd   = ovulationDay + 3           // ±3 days window
ovulationDayStart = max(periodDuration + 1, ovulationDay - 3)

Menstrual  : days 1               → periodDuration       (inclusive)
Follicular : days periodDuration+1 → ovulationDayStart-1  (may be 0 days)
Ovulation  : days ovulationDayStart → ovulationDayEnd
Luteal     : days ovulationDayEnd+1 → cycleLength
```

### Worked examples

| Cycle | Period | M | F | OV | L |
|-------|--------|---|---|----|---|
| 21d   | 5d     | 1–5 | — (0d) | 6–10 | 11–21 (11d) |
| 28d   | 5d     | 1–5 | 6–10 | 11–17 | 18–28 (11d) |
| 35d   | 5d     | 1–5 | 6–17 | 18–24 | 25–35 (11d) |
| 28d   | 7d     | 1–7 | 8–10 | 11–17 | 18–28 (11d) |
| 21d   | 7d     | 1–7 | — (0d) | 8–11 | 12–21 (10d) |

**28-day + 5-day period gives OV=[11-17]** — matches the PRD exactly. ✓

### Fertile Window

Ovulation typically occurs on `ovulationDay`. Sperm viability extends
fertilisation window by ~5 days before and ~1 day after.

```
fertileStart = ovulationDay - 5
fertileEnd   = ovulationDay + 1
```

**Important:** `fertileStart` must be clamped to ≥ 1 (cannot precede cycle
start). This matters for cycles ≤ 19 days.

---

## 5. Cold-Start Handling

When a user completes onboarding with no prior logged cycles, the engine is
seeded from three onboarding values:

| Onboarding field | Maps to | Default |
|---|---|---|
| `lastPeriodDate` | Anchor for first prediction | (required) |
| `estimatedCycleLength` | `seedCycleLength` | 28 |
| `estimatedPeriodDuration` | `seedPeriodDuration` | 5 |

**The seed is not a CycleRecord.** Do not insert a synthetic completed cycle.
Instead, `averageCycleLength` returns `seedCycleLength` when
`completedCycles.isEmpty`. Same for `averagePeriodDuration`.

**Confidence:** `PredictionConfidence.seed` when `completedCycles.isEmpty`.

**As cycles are logged, the engine naturally migrates:**

```
completedCycles.count = 0  → .seed  → "Estimated" label on all predictions
completedCycles.count = 1  → .low   → low-confidence indicator shown
completedCycles.count = 2  → .low   → low-confidence indicator shown
completedCycles.count = 3+ → .high  → full display, no indicator
```

---

## 6. Edge Case Rules

### 6.1 The 14-Day Minimum Gap Rule

**Rule:** If a period-flow log is recorded on a date that is fewer than 14
calendar days after the most recent cycle's start date, treat it as spotting
or continuation of the existing cycle. Do not start a new cycle.

**Applied in two places:**

**A) At logging time (real-time, in the view model):**
```
Let today = date of new log
Let lastCycleStart = startDate of the most recently known cycle
If (today - lastCycleStart) < 14 days → continuation; update existing cycle
If (today - lastCycleStart) ≥ 14 days → new cycle starts
```

**B) At CycleRecord derivation (batch, from raw logs):**
See Section 7 — same 14-day-from-start threshold applied when scanning logs.

**Why 14 days?** The absolute minimum physiologically possible cycle length
for an adult is ~15 days. 14 days is a safe conservative threshold that
catches spotting, implantation bleeding, and data entry errors without
accidentally combining genuinely short cycles.

### 6.2 The 60-Day Confidence Gap Flag

**Rule:** If the number of calendar days between `lastKnownPeriodStart` and
`today` exceeds 60, set `isLowConfidenceDueToGap = true` on the prediction
and surface a prompt: *"It's been a while — can you confirm your last period
date?"*

**This is distinct from confidence tier.** A user with 10 completed cycles
can still trigger this flag if they stop logging for 2 months.

**Implementation check (performed when building `CyclePrediction`):**
```swift
let daysSinceLastPeriod = calendar.dateComponents(
    [.day], from: lastKnownPeriodStart, to: today
).day ?? 0
let isLowConfidenceDueToGap = daysSinceLastPeriod > 60
```

### 6.3 Late Period Detection

**Rule:** If `today > predictedNextPeriodStart` AND no period-flow log exists
on or after `predictedNextPeriodStart`, set `isLate = true`.

Do not conflate this with the 60-day flag — they are independent booleans
that can both be true.

---

## 7. CycleRecord Derivation from Raw Logs

The Supabase `cycle_logs` table stores one row per day. This section defines
the deterministic algorithm for deriving the structured `[CycleRecord]` array
from raw log entries.

### Input

```swift
struct CycleLog {
    let date: Date           // Normalised to start-of-day
    let periodFlow: PeriodFlow?
}

enum PeriodFlow: String {
    case none, spotting, light, medium, heavy
}
```

### Algorithm

```
1. Filter cycle_logs to only entries where periodFlow is NOT nil AND NOT .none
2. Sort filtered entries by date ascending
3. Group entries into "runs" using the 14-day rule:
   - Start the first run with the first entry
   - For each subsequent entry E:
       daysSinceRunStart = E.date - currentRun.first.date  (in calendar days)
       if daysSinceRunStart < 14:
           append E to currentRun
       else:
           close currentRun, start new run with E
4. Discard any run that consists entirely of .spotting logs AND has < 2 days
   duration. (Single-day spotting before a period is ambiguous; keep multi-day
   spotting runs.)
5. Convert each run to a CycleRecord:
   startDate     = run.first.date
   periodDuration = (run.last.date - run.first.date) in days + 1
   cycleLength   = nil (filled in next step)
6. For each consecutive pair (record[i], record[i+1]):
   record[i].cycleLength = (record[i+1].startDate - record[i].startDate) in days
   The last record always has cycleLength = nil (the current ongoing cycle)
7. Return all records. The last record (ongoing cycle) is NOT included in the
   weighted average — only records with non-nil cycleLength are "completed."
```

**Critical:** Step 3 measures gap from the **run start**, not from the last
log in the run. A period that starts March 1 and ends March 6, followed by
spotting on March 12, is still within 14 days of March 1 → same run.

---

## 8. `PredictionEngine` — API Contract

Full Swift source is in `references/swift-implementation.md`. The public API
is:

```swift
final class PredictionEngine {
    init(completedCycles: [CycleRecord],
         seedCycleLength: Int = 28,
         seedPeriodDuration: Int = 5)

    // Derived from weighted rolling average (or seed if no completed cycles)
    var averageCycleLength: Int { get }
    var averagePeriodDuration: Int { get }
    var confidence: PredictionConfidence { get }

    // Core predictions
    func predictNextPeriodStart(from lastPeriodStart: Date) -> Date
    func predictPhases(for cycleStartDate: Date) -> [PhaseInterval]
    func fertileWindow(for cycleStartDate: Date) -> DateInterval

    // Full prediction package (preferred — assembles all fields)
    func prediction(lastPeriodStart: Date, today: Date) -> CyclePrediction
}
```

**Use `prediction(lastPeriodStart:today:)` everywhere in the app.** The
individual methods exist for testing but calling code should not assemble a
`CyclePrediction` manually.

---

## 9. Implementation Rules for Claude Code

1. **Read `references/swift-implementation.md` before coding.** Do not write
   the `PredictionEngine` from scratch — use the provided implementation.

2. **All dates must be normalised to start-of-day** before storing or
   comparing. Use `Calendar.current.startOfDay(for:)`. Never compare raw
   `Date` values for equality in cycle logic.

3. **Use `Calendar.current` for all date arithmetic**, not manual
   seconds-based math. This respects DST and user locale.

4. **`cycleLength` only on completed cycles.** The last `CycleRecord` in the
   array always has `cycleLength = nil`. The weighted average must filter to
   `compactMap { $0.cycleLength }` — do not skip this guard.

5. **Zero-duration follicular phases are valid.** Short cycles (≤21 days with
   ≥5-day period) produce a follicular `PhaseInterval` where
   `startDate == endDate`. Do not crash or assert on this. The UI checks
   `PhaseInterval.isEmpty` and skips rendering.

6. **Do not write prediction logic in views or view models.** All prediction
   logic lives in `PredictionEngine`. View models call `prediction(...)` and
   expose the result. Views bind to view model outputs.

7. **`PredictionEngine` is a pure value transformer** — no network calls, no
   Supabase queries, no side effects. It takes data in, returns predictions
   out. Test it without mocks.

---

## 10. Testing Requirements

Full test source is in `references/unit-tests.md`. Required coverage:

| Test case | What it verifies |
|---|---|
| `testStandard28DayCycle` | Weighted avg, phases, fertile window |
| `testShortCycle21Days` | Phase boundaries, zero-duration follicular |
| `testLongCycle35Days` | Phase boundaries, late ovulation |
| `testIrregularCycles` | Weighted avg tracks trend vs. simple avg |
| `testSingleCycle` | Works with n=1; confidence = .low |
| `testColdStart` | No completed cycles; seed fallback; confidence = .seed |
| `test14DaySpottingRule_CycleRecord` | Spotting < 14d from run start → same run |
| `test14DaySpottingRule_NewCycle` | Log ≥ 14d from last start → new cycle |
| `test60DayConfidenceFlag` | `isLowConfidenceDueToGap = true` at day 61 |
| `test60DayConfidenceFlag_NotTriggered` | Not flagged at day 59 |
| `testLateDetection` | `isLate = true` when predicted date passes |
| `testConfidenceTiers` | 0→.seed, 1→.low, 2→.low, 3→.high |
| `testOvulationDayAnchor` | ovulationDay = cycleLength - 14 for all lengths |
| `testFertileWindowClamping` | Clamps to ≥ cycle day 1 for very short cycles |
