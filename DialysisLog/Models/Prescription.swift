import Foundation
import SwiftData

/// What the unit prescribed, entered by the patient from their own prescription.
///
/// **The app never sets any of this and never suggests changing it.** It does not choose a
/// dextrose strength, a fill volume, a dwell time or a dry weight; those come from the renal
/// unit, and every number here is typed in from what the unit wrote down. What the app does is
/// record what actually happened and put it next to what was prescribed, which is exactly what
/// the paper flow sheet from the unit does.
@Model
final class Prescription {
    var id: UUID = UUID()
    var modalityRaw: String = Modality.capd.rawValue

    /// The weight the unit is aiming for, and the fluid removal they asked for each day.
    var dryWeightKg: Double = 0
    var targetDailyUFml: Double = 0

    // Peritoneal dialysis, as written on the prescription.
    var exchangesPerDay: Int = 4
    var fillVolumeML: Double = 2000
    var dwellMinutes: Int = 240
    var usualDextrose: String = "2.5"
    /// Automated cycler settings, for anyone on APD.
    var cyclerTotalVolumeML: Double = 0
    var cyclerCycles: Int = 0
    var lastFillVolumeML: Double = 0

    // Home haemodialysis, as written on the prescription.
    var treatmentsPerWeek: Int = 5
    var treatmentMinutes: Int = 180
    var bloodFlowRate: Int = 0
    var dialysateFlowRate: Int = 0

    // Who to ring, which is the number people cannot find when they need it.
    var unitName: String = ""
    var unitPhone: String = ""
    var nurseName: String = ""
    var notes: String = ""

    init() { self.id = UUID() }

    var modality: Modality {
        get { Modality(rawValue: modalityRaw) ?? .capd }
        set { modalityRaw = newValue.rawValue }
    }
}

enum Modality: String, CaseIterable, Identifiable {
    case capd, apd, homeHD
    var id: String { rawValue }

    var name: String {
        switch self {
        case .capd: return "CAPD — manual exchanges"
        case .apd: return "APD — cycler overnight"
        case .homeHD: return "Home haemodialysis"
        }
    }

    var shortName: String {
        switch self {
        case .capd: return "CAPD"
        case .apd: return "APD"
        case .homeHD: return "Home HD"
        }
    }

    var isPeritoneal: Bool { self != .homeHD }

    /// What one entry in the log is called on this modality.
    var treatmentNoun: String { isPeritoneal ? "exchange" : "session" }
    var treatmentNounPlural: String { isPeritoneal ? "exchanges" : "sessions" }
}

/// The dextrose strengths sold for peritoneal dialysis, offered so nobody has to type them.
/// Listing what exists is not the same as recommending one; which bag to hang is the unit's
/// call and the app never makes it.
enum DextroseStrength: String, CaseIterable, Identifiable {
    case low = "1.5", medium = "2.5", high = "4.25", icodextrin = "Icodextrin", other = "Other"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .icodextrin, .other: return rawValue
        default: return "\(rawValue)%"
        }
    }
}

/// What the drained fluid looked like. This is an observation the patient records, not a
/// diagnosis the app makes — but cloudy effluent is the one every unit teaches people to ring
/// about the same day, so the app says so rather than leaving it as a neutral tick box.
enum EffluentAppearance: String, CaseIterable, Identifiable {
    case clear, cloudy, fibrin, bloodTinged
    var id: String { rawValue }

    var name: String {
        switch self {
        case .clear: return "Clear"
        case .cloudy: return "Cloudy"
        case .fibrin: return "Fibrin strands"
        case .bloodTinged: return "Blood-tinged"
        }
    }

    /// Whether the unit asks to hear about it, in the words units use when they teach it.
    var advice: String? {
        switch self {
        case .clear: return nil
        case .cloudy:
            return "Cloudy drain is the sign units ask to be told about the same day. Ring your unit — do not wait for the next visit."
        case .fibrin:
            return "Fibrin strands happen. Units usually still want to know, especially if they are new or increasing."
        case .bloodTinged:
            return "Tell your unit. It can be minor, and they would rather hear it from you than read it later."
        }
    }

    var needsACall: Bool { self == .cloudy }

    var symbol: String {
        switch self {
        case .clear: return "checkmark.circle.fill"
        case .cloudy: return "exclamationmark.triangle.fill"
        case .fibrin: return "line.3.horizontal"
        case .bloodTinged: return "drop.fill"
        }
    }
}
