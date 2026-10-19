import Foundation
import PDFKit
import UIKit

/// The sheet you take to the monthly visit.
///
/// A renal unit reviews a month at a time, and the nurse is looking for three things: whether
/// the fluid is coming off, what the weight and pressure are doing, and anything that was
/// reported. So the sheet leads with those, then prints the days, and says plainly where a day
/// is missing instead of quietly closing the gap.
enum PDFExporter {
    static func export(_ days: [DayRecord], prescription: Prescription?,
                       month: Date = .now) throws -> URL {
        let calendar = Calendar.current
        let inMonth = days
            .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .sorted { $0.date < $1.date }

        let pageWidth: CGFloat = 612, pageHeight: CGFloat = 792, margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(ISO8601DateFormatter.day.string(from: month)).pdf")

        try renderer.writePDF(to: url) { ctx in
            var y: CGFloat = margin
            ctx.beginPage()

            func line(_ text: String, size: CGFloat = 11, weight: UIFont.Weight = .regular,
                      colour: UIColor = .label, indent: CGFloat = 0, gapAfter: CGFloat = 4) {
                let font = UIFont.systemFont(ofSize: size, weight: weight)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
                let width = pageWidth - margin * 2 - indent
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                if y + bounding.height > pageHeight - margin { ctx.beginPage(); y = margin }
                (text as NSString).draw(
                    with: CGRect(x: margin + indent, y: y, width: width, height: bounding.height),
                    options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                y += bounding.height + gapAfter
            }
            func rule(gap: CGFloat = 10) {
                y += gap / 2
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                UIColor.separator.setStroke(); path.lineWidth = 0.5; path.stroke()
                y += gap / 2
            }

            line("Dialysis log", size: 22, weight: .semibold)
            line(month.formatted(.dateTime.month(.wide).year()), size: 12, colour: .secondaryLabel)
            rule()

            if let p = prescription {
                line("As prescribed", size: 12, weight: .semibold, gapAfter: 4)
                line(p.modality.name, size: 10, gapAfter: 2)
                var written: [String] = []
                if p.modality.isPeritoneal {
                    if p.exchangesPerDay > 0 { written.append("\(p.exchangesPerDay) exchanges/day") }
                    if p.fillVolumeML > 0 { written.append("\(Int(p.fillVolumeML)) mL fill") }
                    if p.dwellMinutes > 0 { written.append("\(p.dwellMinutes) min dwell") }
                    if !p.usualDextrose.isEmpty { written.append("usual \(p.usualDextrose)") }
                } else {
                    if p.treatmentsPerWeek > 0 { written.append("\(p.treatmentsPerWeek) sessions/week") }
                    if p.treatmentMinutes > 0 { written.append("\(p.treatmentMinutes) min") }
                    if p.bloodFlowRate > 0 { written.append("BFR \(p.bloodFlowRate)") }
                }
                if p.dryWeightKg > 0 { written.append("dry weight \(short(p.dryWeightKg)) kg") }
                if p.targetDailyUFml > 0 { written.append("target UF \(Int(p.targetDailyUFml)) mL/day") }
                line(written.joined(separator: "  ·  "), size: 10, colour: .secondaryLabel)
                if !p.unitName.isEmpty {
                    line("Unit: \(p.unitName)\(p.unitPhone.isEmpty ? "" : "  ·  \(p.unitPhone)")",
                         size: 10, colour: .secondaryLabel)
                }
                rule()
            }

            // The three numbers the nurse looks for first.
            let logged = inMonth.filter { !$0.sortedTreatments.isEmpty || $0.hasVitals }
            let ufDays = inMonth.compactMap(\.totalUF)
            let averageUF = ufDays.isEmpty ? nil : ufDays.reduce(0, +) / Double(ufDays.count)
            let flagged = inMonth.filter { !$0.flags.isEmpty }
            let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30

            line("\(logged.count) of \(daysInMonth) days recorded"
                 + (averageUF.map { "  ·  average UF \(Int($0)) mL/day" } ?? "  ·  no fluid figures recorded")
                 + (flagged.isEmpty ? "" : "  ·  \(flagged.count) days reported to the unit"),
                 size: 11, weight: .semibold,
                 colour: flagged.isEmpty ? .label : .systemOrange)
            if logged.count < daysInMonth {
                line("\(daysInMonth - logged.count) days have nothing recorded.",
                     size: 10, colour: .secondaryLabel)
            }
            rule()

            if inMonth.isEmpty {
                line("Nothing was recorded for this month.", colour: .secondaryLabel)
            }

            for record in inMonth {
                var head = ISO8601DateFormatter.day.string(from: record.date)
                if record.weightKg > 0 { head += "   \(short(record.weightKg)) kg" }
                if record.systolic > 0 { head += "   \(record.systolic)/\(record.diastolic)" }
                if let uf = record.totalUF { head += "   UF \(Int(uf)) mL" }
                line(head, size: 10, weight: .semibold, gapAfter: 1)

                for t in record.sortedTreatments {
                    var parts = [t.time.formatted(date: .omitted, time: .shortened)]
                    if t.kind.isPeritoneal {
                        if !t.dextrose.isEmpty { parts.append(t.dextrose) }
                        if t.fillML > 0 { parts.append("in \(Int(t.fillML))") }
                        if t.drainML > 0 { parts.append("out \(Int(t.drainML))") }
                        if let uf = t.ultrafiltration { parts.append("UF \(Int(uf))") }
                        if let appearance = t.appearance, appearance != .clear {
                            parts.append(appearance.name)
                        }
                    } else {
                        if t.minutes > 0 { parts.append("\(t.minutes) min") }
                        if t.bloodFlowRate > 0 { parts.append("BFR \(t.bloodFlowRate)") }
                        if t.ufAchievedML > 0 { parts.append("UF \(Int(t.ufAchievedML))") }
                        if t.preWeightKg > 0 && t.postWeightKg > 0 {
                            parts.append("\(short(t.preWeightKg))→\(short(t.postWeightKg)) kg")
                        }
                    }
                    let flagged = t.appearance?.needsACall == true
                    line(parts.joined(separator: "  ·  "), size: 9,
                         weight: flagged ? .semibold : .regular,
                         colour: flagged ? .systemOrange : .secondaryLabel,
                         indent: 14, gapAfter: 1)
                    if !t.notes.isEmpty {
                        line(t.notes, size: 9, colour: .secondaryLabel, indent: 24, gapAfter: 1)
                    }
                }
                if !record.symptoms.isEmpty {
                    line(record.symptoms, size: 9, indent: 14, gapAfter: 1)
                }
                if !record.notes.isEmpty {
                    line(record.notes, size: 9, colour: .secondaryLabel, indent: 14, gapAfter: 1)
                }
                y += 2
            }

            rule()
            line("Every figure above was entered by the patient. \(AppConfig.appName) is a diary: "
                 + "it records the prescription the renal unit set and what actually happened "
                 + "against it. It does not set or change a prescription, does not advise on "
                 + "treatment, and is not a medical device.",
                 size: 9, colour: .secondaryLabel)
        }
        return url
    }

    private static func short(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
