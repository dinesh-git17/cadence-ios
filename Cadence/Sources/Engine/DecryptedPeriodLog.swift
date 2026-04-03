import Foundation

/// Lightweight bridge between the encrypted CycleLog and the prediction engine.
/// The calling layer decrypts CycleLog.periodFlow, maps to this type,
/// then passes to CycleRecordDeriver.
struct DecryptedPeriodLog {
    let date: Date
    let periodFlow: PeriodFlow?
}
