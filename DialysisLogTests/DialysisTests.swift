import Testing
import Foundation
import PDFKit
@testable import DialysisLog

/// Fluid removed is drained minus filled. The interesting cases are the ones where the app
/// must refuse to answer.
struct UltrafiltrationTests {
    private func exchange(fill: Double, drain: Double) -> Treatment {
        let t = Treatment(time: .now, kind: .manualExchange)
        t.fillML = fill; t.drainML = drain
        return t
    }

    @Test func drainedMinusFilled() {
        #expect(exchange(fill: 2000, drain: 2260).ultrafiltration == 260)
    }

    @Test func aMissingFigureMeansNoAnswer() {
        // Guessing the other number would put a fabricated millilitre count in front of a nurse.
        #expect(exchange(fill: 2000, drain: 0).ultrafiltration == nil)
        #expect(exchange(fill: 0, drain: 2200).ultrafiltration == nil)
        #expect(exchange(fill: 0, drain: 0).ultrafiltration == nil)
    }

    @Test func moreInThanOutIsReportedNotHidden() {
        let t = exchange(fill: 2000, drain: 1880)
        #expect(t.ultrafiltration == -120)
        #expect(t.isNegativeUF)
    }

    @Test func aHaemodialysisSessionUsesWhatTheMachineAchieved() {
        let t = Treatment(time: .now, kind: .hdSession)
        #expect(t.ultrafiltration == nil, "nothing recorded yet")
        t.ufAchievedML = 1800
        #expect(t.ultrafiltration == 1800)
        t.fillML = 2000; t.drainML = 900
        #expect(t.ultrafiltration == 1800, "fill and drain are meaningless on haemodialysis")
    }

    @Test func weightChangeNeedsBothWeights() {
        let t = Treatment(time: .now, kind: .hdSession)
        t.preWeightKg = 76.4
        #expect(t.weightChange == nil)
        t.postWeightKg = 74.2
        #expect(t.weightChange.map { ($0 * 10).rounded() / 10 } == -2.2)
    }
}

struct DayTests {
    private func day(_ exchanges: [(fill: Double, drain: Double)]) -> DayRecord {
        let d = DayRecord(date: .now)
        d.treatments = exchanges.enumerated().map { index, spec in
            let t = Treatment(time: Calendar.current.date(byAdding: .hour, value: index, to: .now)!,
                              kind: .manualExchange)
            t.fillML = spec.fill; t.drainML = spec.drain
            t.day = d
            return t
        }
        return d
    }

    @Test func theDayAddsUpWhatCameOff() {
        #expect(day([(2000, 2200), (2000, 2300)]).totalUF == 500)
    }

    @Test func aDayWithNothingUsableHasNoTotalRatherThanZero() {
        // A day with no drains written down is a gap, not a day where no fluid came off.
        #expect(day([]).totalUF == nil)
        #expect(day([(2000, 0)]).totalUF == nil)
    }

    @Test func aPartlyRecordedDayTotalsOnlyWhatIsThere() {
        #expect(day([(2000, 2250), (2000, 0)]).totalUF == 250)
    }

    @Test func theTotalCanBeNegative() {
        #expect(day([(2000, 1900), (2000, 1950)]).totalUF == -150)
    }

    @Test func comparingAgainstTargetNeedsBothNumbers() {
        let d = day([(2000, 2400)])
        #expect(d.ufAgainstTarget(nil) == nil)
        let p = Prescription()
        #expect(d.ufAgainstTarget(p) == nil, "no target set, so nothing to compare against")
        p.targetDailyUFml = 800
        #expect(d.ufAgainstTarget(p) == -400)
    }

    @Test func aCloudyDrainIsFlaggedForTheDay() {
        let d = day([(2000, 2200), (2000, 2100)])
        #expect(d.flags.isEmpty)
        d.sortedTreatments[1].appearance = .cloudy
        #expect(d.flags.count == 1)
        d.sortedTreatments[0].appearance = .fibrin
        #expect(d.flags.count == 1, "fibrin is worth telling the unit, but it is not the same call")
    }
}

/// The app records observations; it never diagnoses. What it does do is repeat the thing
/// every unit teaches: a cloudy drain is a same-day phone call.
struct AppearanceTests {
    @Test func clearNeedsNoAdvice() {
        #expect(EffluentAppearance.clear.advice == nil)
        #expect(!EffluentAppearance.clear.needsACall)
    }

    @Test func onlyCloudyIsASameDayCall() {
        #expect(EffluentAppearance.cloudy.needsACall)
        #expect(!EffluentAppearance.fibrin.needsACall)
        #expect(!EffluentAppearance.bloodTinged.needsACall)
    }

    @Test func everyAbnormalAppearanceSaysSomething() {
        for appearance in EffluentAppearance.allCases where appearance != .clear {
            #expect(appearance.advice?.isEmpty == false, "\(appearance) needs wording")
        }
    }

    @Test func theAdviceIsToRingTheUnitNotADiagnosis() {
        let text = EffluentAppearance.cloudy.advice ?? ""
        #expect(text.lowercased().contains("ring your unit"))
        #expect(!text.lowercased().contains("peritonitis"), "the app reports what was seen, it does not name a condition")
    }
}

struct ModalityTests {
    @Test func capdOffersManualExchangesOnly() {
        #expect(TreatmentKind.kinds(for: .capd) == [.manualExchange])
    }

    @Test func apdOffersTheCyclerAndAManualTopUp() {
        #expect(TreatmentKind.kinds(for: .apd).contains(.cyclerSession))
        #expect(TreatmentKind.kinds(for: .apd).contains(.manualExchange))
    }

    @Test func homeHaemodialysisOffersSessionsOnly() {
        #expect(TreatmentKind.kinds(for: .homeHD) == [.hdSession])
        #expect(!Modality.homeHD.isPeritoneal)
    }

    @Test func theNounFollowsTheModality() {
        #expect(Modality.capd.treatmentNoun == "exchange")
        #expect(Modality.homeHD.treatmentNoun == "session")
    }
}

struct ExportTests {
    private func loaded() -> (days: [DayRecord], prescription: Prescription) {
        let p = Prescription()
        p.modality = .capd
        p.exchangesPerDay = 4
        p.fillVolumeML = 2000
        p.dwellMinutes = 240
        p.usualDextrose = "2.5"
        p.dryWeightKg = 74
        p.targetDailyUFml = 800
        p.unitName = "Northfield Renal Unit"
        p.unitPhone = "555 0114"

        let calendar = Calendar.current
        var days: [DayRecord] = []
        for offset in 0..<2 {
            let d = DayRecord(date: calendar.date(byAdding: .day, value: -offset, to: .now)!)
            d.weightKg = 74.6
            d.systolic = 132; d.diastolic = 78
            var list: [Treatment] = []
            for hour in [7, 13] {
                let t = Treatment(time: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: d.date)!,
                                  kind: .manualExchange)
                t.dextrose = "2.5"; t.fillML = 2000; t.drainML = 2250
                t.appearance = .clear
                t.day = d
                list.append(t)
            }
            if offset == 0 {
                list[1].appearance = .cloudy
                list[1].notes = "Rang the unit, taking a sample in."
            }
            d.treatments = list
            days.append(d)
        }
        return (days, p)
    }

    @Test func csvHasAHeaderAndOneRowPerTreatment() throws {
        let (days, _) = loaded()
        let text = try String(contentsOf: try CSVExporter.export(days), encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 5)
        #expect(lines[0].hasPrefix("date,time,kind,weight_kg"))
    }

    @Test func csvLeavesUnrecordedFiguresBlank() throws {
        let (days, _) = loaded()
        let text = try String(contentsOf: try CSVExporter.export(days), encoding: .utf8)
        // Peritoneal rows carry no haemodialysis figures; those columns must be empty, not 0.
        #expect(!text.contains(",0,0,0,"))
        #expect(text.contains("250"), "the worked-out ultrafiltration is carried")
    }

    @Test func csvStillRecordsADayWithVitalsButNoTreatments() throws {
        let day = DayRecord(date: .now)
        day.weightKg = 75.2
        day.systolic = 128; day.diastolic = 74
        let text = try String(contentsOf: try CSVExporter.export([day]), encoding: .utf8)
        #expect(text.split(separator: "\n").count == 2)
        #expect(text.contains("75.2"))
    }

    @Test func thePdfLeadsWithWhatTheNurseChecksFirst() throws {
        let (days, p) = loaded()
        let url = try PDFExporter.export(days, prescription: p)
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("Dialysis log"))
        #expect(text.contains("CAPD"))
        #expect(text.contains("average UF 500 mL/day"))
        #expect(text.contains("1 days reported to the unit"))
    }

    @Test func thePdfPrintsWhatWasPrescribed() throws {
        let (days, p) = loaded()
        let url = try PDFExporter.export(days, prescription: p)
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("4 exchanges/day"))
        #expect(text.contains("dry weight 74 kg"))
        #expect(text.contains("Northfield Renal Unit"))
    }

    @Test func thePdfNamesTheMissingDaysRatherThanClosingTheGap() throws {
        let (days, p) = loaded()
        let url = try PDFExporter.export(days, prescription: p)
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("days have nothing recorded"))
    }

    @Test func thePdfDisclaimsBeingAClinician() throws {
        let (days, p) = loaded()
        let url = try PDFExporter.export(days, prescription: p)
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("does not set or change a prescription"))
        #expect(text.contains("is not a medical device"))
    }

    @Test func anEmptyMonthSaysSo() throws {
        let url = try PDFExporter.export([], prescription: nil)
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("Nothing was recorded for this month"))
    }
}
