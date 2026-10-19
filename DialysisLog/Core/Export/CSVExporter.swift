import Foundation

/// One row per treatment, with the day's vitals repeated against each, which is the shape a
/// renal unit's spreadsheet expects.
enum CSVExporter {
    static func export(_ days: [DayRecord]) throws -> URL {
        var rows = ["date,time,kind,weight_kg,systolic,diastolic,pulse,temperature_c,"
                    + "dextrose,fill_ml,drain_ml,ultrafiltration_ml,dwell_minutes,appearance,"
                    + "hd_minutes,blood_flow,dialysate_flow,uf_goal_ml,uf_achieved_ml,"
                    + "pre_weight_kg,post_weight_kg,symptoms,notes"]
        for day in days.sorted(by: { $0.date < $1.date }) {
            let stamp = ISO8601DateFormatter.day.string(from: day.date)
            let treatments = day.sortedTreatments
            if treatments.isEmpty {
                rows.append(([stamp, "", "", num(day.weightKg), int(day.systolic), int(day.diastolic),
                              int(day.pulse), num(day.temperatureC)]
                             + Array(repeating: "", count: 13)
                             + [day.symptoms, day.notes]).map(escape).joined(separator: ","))
                continue
            }
            for t in treatments {
                rows.append([
                    stamp, t.time.formatted(date: .omitted, time: .shortened), t.kind.name,
                    num(day.weightKg), int(day.systolic), int(day.diastolic), int(day.pulse),
                    num(day.temperatureC),
                    t.dextrose, num(t.fillML), num(t.drainML),
                    t.ultrafiltration.map { String(Int($0)) } ?? "",
                    int(t.dwellMinutes), t.appearance?.name ?? "",
                    int(t.minutes), int(t.bloodFlowRate), int(t.dialysateFlowRate),
                    num(t.ufGoalML), num(t.ufAchievedML),
                    num(t.preWeightKg), num(t.postWeightKg),
                    day.symptoms, t.notes,
                ].map(escape).joined(separator: ","))
            }
        }
        let text = rows.joined(separator: "\n") + "\n"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(ISO8601DateFormatter.day.string(from: .now)).csv")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// A zero is "not recorded" everywhere in this app, so it is left blank rather than
    /// printed as a measurement nobody took.
    private static func num(_ value: Double) -> String {
        value == 0 ? "" : (value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value))
    }

    private static func int(_ value: Int) -> String { value == 0 ? "" : String(value) }

    private static func escape(_ value: String) -> String {
        value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
            ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            : value
    }
}

extension ISO8601DateFormatter {
    static let day: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
