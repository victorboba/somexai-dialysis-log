import Foundation
import SwiftData

/// Debug fixtures: a fortnight of CAPD with one cloudy drain in it, because a log where
/// everything is clear shows nothing about what the app is for.
enum SampleData {
    static func insert(into context: ModelContext) {
        let prescription = Prescription()
        prescription.modality = .capd
        prescription.exchangesPerDay = 4
        prescription.fillVolumeML = 2000
        prescription.dwellMinutes = 240
        prescription.usualDextrose = DextroseStrength.medium.rawValue
        prescription.dryWeightKg = 74
        prescription.targetDailyUFml = 800
        prescription.unitName = "Northfield Renal Unit"
        prescription.unitPhone = "555 0114"
        prescription.nurseName = "Sister Amara Nwosu"
        context.insert(prescription)

        let calendar = Calendar.current
        for offset in (0..<14).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            let record = DayRecord(date: date)
            record.weightKg = 74.0 + Double.random(in: -0.8...1.2)
            record.systolic = Int.random(in: 118...146)
            record.diastolic = Int.random(in: 68...86)
            record.pulse = Int.random(in: 62...84)
            context.insert(record)

            // Four exchanges, roughly six hours apart.
            for (index, hour) in [7, 12, 17, 22].enumerated() {
                guard let time = calendar.date(bySettingHour: hour, minute: [10, 35, 5, 40][index],
                                               second: 0, of: date) else { continue }
                let t = Treatment(time: time, kind: .manualExchange)
                t.dextrose = index == 3 ? DextroseStrength.high.rawValue : DextroseStrength.medium.rawValue
                t.fillML = 2000
                t.drainML = 2000 + Double(Int.random(in: 120...330))
                t.dwellMinutes = index == 3 ? 480 : 240
                t.appearance = .clear
                // Day four: the cloudy drain that gets rung in.
                if offset == 10 && index == 1 {
                    t.appearance = .cloudy
                    t.notes = "Rang the unit. Told to bring a sample in."
                    t.drainML = 2000 + 60
                }
                if offset == 9 && index == 0 {
                    t.appearance = .fibrin
                }
                // One day the fluid went the wrong way.
                if offset == 3 && index == 2 {
                    t.drainML = 1880
                    t.notes = "Long dwell, hot day."
                }
                t.day = record
                context.insert(t)
            }

            if offset == 10 {
                record.symptoms = "Tender abdomen, felt off all morning."
                record.temperatureC = 37.6
            }
        }
        try? context.save()
    }
}
