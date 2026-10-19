import Foundation
import SwiftData

/// One day on dialysis: the morning numbers, and every treatment done that day.
///
/// The day is the unit of the paper flow sheet units hand out, and the unit of the monthly
/// review, so it is the unit here too.
@Model
final class DayRecord {
    var id: UUID = UUID()
    var date: Date = Date()

    var weightKg: Double = 0
    var systolic: Int = 0
    var diastolic: Int = 0
    var pulse: Int = 0
    var temperatureC: Double = 0
    /// Swelling, shortness of breath, exit site — the things the nurse asks about at the visit.
    var symptoms: String = ""
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Treatment.day)
    var treatments: [Treatment]? = nil

    init(date: Date = .now) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
    }

    var sortedTreatments: [Treatment] {
        (treatments ?? []).sorted { $0.time < $1.time }
    }

    /// Fluid removed across the day: the sum of what each treatment took off.
    ///
    /// Nil rather than zero when nothing usable was recorded, because a day with no drains
    /// written down is a gap, not a day where no fluid came off.
    var totalUF: Double? {
        let contributing = sortedTreatments.compactMap(\.ultrafiltration)
        return contributing.isEmpty ? nil : contributing.reduce(0, +)
    }

    var hasVitals: Bool { weightKg > 0 || systolic > 0 }

    /// Anything the patient recorded that units ask to hear about promptly.
    var flags: [Treatment] {
        sortedTreatments.filter { $0.appearance?.needsACall == true }
    }

    /// How far the day's fluid removal sits from what was prescribed — arithmetic on two
    /// numbers the user entered, not a target the app invented.
    func ufAgainstTarget(_ prescription: Prescription?) -> Double? {
        guard let total = totalUF, let target = prescription?.targetDailyUFml, target > 0 else { return nil }
        return total - target
    }
}

/// One exchange, or one haemodialysis session. Which fields matter depends on the modality,
/// and the editor only ever shows the ones that do.
@Model
final class Treatment {
    var id: UUID = UUID()
    var time: Date = Date()
    var kindRaw: String = TreatmentKind.manualExchange.rawValue

    // Peritoneal.
    var dextrose: String = ""
    var fillML: Double = 0
    var drainML: Double = 0
    var dwellMinutes: Int = 0
    var appearanceRaw: String = ""

    // Haemodialysis.
    var minutes: Int = 0
    var bloodFlowRate: Int = 0
    var dialysateFlowRate: Int = 0
    var ufGoalML: Double = 0
    var ufAchievedML: Double = 0
    var preWeightKg: Double = 0
    var postWeightKg: Double = 0
    var preSystolic: Int = 0
    var preDiastolic: Int = 0
    var postSystolic: Int = 0
    var postDiastolic: Int = 0

    var notes: String = ""
    var day: DayRecord? = nil

    init(time: Date = .now, kind: TreatmentKind = .manualExchange) {
        self.id = UUID()
        self.time = time
        self.kindRaw = kind.rawValue
    }

    var kind: TreatmentKind {
        get { TreatmentKind(rawValue: kindRaw) ?? .manualExchange }
        set { kindRaw = newValue.rawValue }
    }

    var appearance: EffluentAppearance? {
        get { appearanceRaw.isEmpty ? nil : EffluentAppearance(rawValue: appearanceRaw) }
        set { appearanceRaw = newValue?.rawValue ?? "" }
    }

    /// Fluid removed by this treatment.
    ///
    /// On peritoneal dialysis that is drained minus filled, which is the subtraction people do
    /// in their heads at the drain bag and get wrong when they are tired. Nil when either
    /// figure is missing: there is no honest answer from one number, and guessing the other
    /// would put a fabricated millilitre count in front of a nurse.
    var ultrafiltration: Double? {
        switch kind {
        case .manualExchange, .cyclerSession:
            guard fillML > 0, drainML > 0 else { return nil }
            return drainML - fillML
        case .hdSession:
            return ufAchievedML > 0 ? ufAchievedML : nil
        }
    }

    /// A negative UF means more went in than came out. It happens, and it is worth seeing.
    var isNegativeUF: Bool {
        guard let uf = ultrafiltration else { return false }
        return uf < 0
    }

    var weightChange: Double? {
        guard preWeightKg > 0, postWeightKg > 0 else { return nil }
        return postWeightKg - preWeightKg
    }
}

enum TreatmentKind: String, CaseIterable, Identifiable {
    case manualExchange, cyclerSession, hdSession
    var id: String { rawValue }

    var name: String {
        switch self {
        case .manualExchange: return "Manual exchange"
        case .cyclerSession: return "Cycler session"
        case .hdSession: return "Haemodialysis session"
        }
    }

    var isPeritoneal: Bool { self != .hdSession }

    static func kinds(for modality: Modality) -> [TreatmentKind] {
        switch modality {
        case .capd: return [.manualExchange]
        case .apd: return [.cyclerSession, .manualExchange]
        case .homeHD: return [.hdSession]
        }
    }

    var symbol: String {
        switch self {
        case .manualExchange: return "drop.circle"
        case .cyclerSession: return "moon.zzz"
        case .hdSession: return "waveform.path.ecg"
        }
    }
}
