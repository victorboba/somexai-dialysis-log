import SwiftUI
import SwiftData

/// Today, first.
///
/// Every other app in this portfolio opens on a list of things to inspect. This one opens on
/// today, because someone on CAPD does four or five exchanges a day, every day, and the only
/// question on the way in is what is left to record. The month behind it is for the visit.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DayRecord.date, order: .reverse) private var days: [DayRecord]
    @Query private var prescriptions: [Prescription]

    @State private var editingTreatment: Treatment?
    @State private var addingTreatment = false
    @State private var openDay: DayRecord?
    @State private var showingPrescription = false
    @State private var showingSettings = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var prescription: Prescription? { prescriptions.first }

    private var today: DayRecord? {
        days.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TodayCard(day: today, prescription: prescription)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }

                Section {
                    Button { addTreatment() } label: {
                        Label("Record \(article) \(noun)", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    Button { openToday() } label: {
                        Label("Today's weight and blood pressure", systemImage: "heart.text.square")
                    }
                }

                if let today, !today.sortedTreatments.isEmpty {
                    Section("Today") {
                        ForEach(today.sortedTreatments) { treatment in
                            Button { editingTreatment = treatment } label: {
                                TreatmentRow(treatment: treatment)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in deleteTreatments(offsets, from: today) }
                    }
                }

                Section {
                    ForEach(recentDays) { day in
                        Button { openDay = day } label: { DayRow(day: day, prescription: prescription) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Text("Earlier")
                } footer: {
                    if recentDays.isEmpty {
                        Text("Days you record will build up here, and the monthly sheet is what you take to the visit.")
                    }
                }
            }
            .navigationTitle("Dialysis log")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { HowToView() } label: {
                        Label("How do I use this app?", systemImage: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingPrescription = true } label: {
                            Label("My prescription", systemImage: "list.clipboard")
                        }
                        Divider()
                        Button { exportPDF() } label: {
                            Label("This month's sheet (PDF)", systemImage: "doc.richtext")
                        }
                        Button { exportCSV() } label: {
                            Label("Everything as CSV", systemImage: "tablecells")
                        }
                        Divider()
                        Button { showingSettings = true } label: { Label("Settings", systemImage: "gear") }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editingTreatment) { treatment in
                TreatmentEditorView(treatment: treatment, prescription: prescription)
            }
            .sheet(isPresented: $addingTreatment) {
                if let day = today ?? makeToday() {
                    TreatmentEditorView(treatment: nil, day: day, prescription: prescription)
                }
            }
            .sheet(item: $openDay) { DayEditorView(day: $0, prescription: prescription) }
            .sheet(isPresented: $showingPrescription) {
                PrescriptionView(prescription: prescription ?? makePrescription())
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private var noun: String { prescription?.modality.treatmentNoun ?? "exchange" }
    private var article: String { noun.first == "e" ? "an" : "a" }

    private var recentDays: [DayRecord] {
        days.filter { !Calendar.current.isDateInToday($0.date) }.prefix(21).map { $0 }
    }

    @discardableResult
    private func makeToday() -> DayRecord? {
        if let today { return today }
        let record = DayRecord(date: .now)
        context.insert(record)
        try? context.save()
        return record
    }

    private func makePrescription() -> Prescription {
        if let prescription { return prescription }
        let new = Prescription()
        context.insert(new)
        try? context.save()
        return new
    }

    private func addTreatment() {
        makeToday()
        addingTreatment = true
    }

    private func openToday() {
        openDay = makeToday()
    }

    private func deleteTreatments(_ offsets: IndexSet, from day: DayRecord) {
        let list = day.sortedTreatments
        for index in offsets { context.delete(list[index]) }
        try? context.save()
        WidgetSync.update(with: days, prescription: prescription)
    }

    private func exportPDF() {
        do { exportFile = ExportFile(url: try PDFExporter.export(days, prescription: prescription)) }
        catch { exportError = error.localizedDescription }
    }

    private func exportCSV() {
        do { exportFile = ExportFile(url: try CSVExporter.export(days)) }
        catch { exportError = error.localizedDescription }
    }
}

/// The card that answers "where am I today".
private struct TodayCard: View {
    let day: DayRecord?
    let prescription: Prescription?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                if let uf = day?.totalUF {
                    Text("\(Int(uf))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(uf < 0 ? .orange : .primary)
                    Text("mL off today").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("nothing recorded yet").font(.subheadline).foregroundStyle(.secondary)
                }
            }

            if let target = prescription?.targetDailyUFml, target > 0, let uf = day?.totalUF {
                let difference = uf - target
                Text(difference >= 0
                     ? "\(Int(difference)) mL above the \(Int(target)) mL your unit asked for"
                     : "\(Int(-difference)) mL short of the \(Int(target)) mL your unit asked for")
                    .font(.caption)
                    .foregroundStyle(difference >= 0 ? Color.secondary : Color.orange)
            }

            HStack(spacing: 16) {
                if let count = day?.sortedTreatments.count, count > 0 {
                    Stat(value: "\(count)", label: expectedLabel(count))
                }
                if let weight = day?.weightKg, weight > 0 {
                    Stat(value: short(weight), label: "kg")
                }
                if let systolic = day?.systolic, systolic > 0, let diastolic = day?.diastolic {
                    Stat(value: "\(systolic)/\(diastolic)", label: "mmHg")
                }
                Spacer(minLength: 0)
            }

            if let flags = day?.flags, !flags.isEmpty {
                Label("Cloudy drain recorded today — your unit asks to hear about this the same day.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private func expectedLabel(_ count: Int) -> String {
        guard let prescribed = prescription?.exchangesPerDay, prescribed > 0,
              prescription?.modality.isPeritoneal == true else {
            return prescription?.modality.treatmentNounPlural ?? "recorded"
        }
        return "of \(prescribed)"
    }

    private func short(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct TreatmentRow: View {
    let treatment: Treatment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: treatment.kind.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(treatment.time.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                if let appearance = treatment.appearance, appearance != .clear {
                    Label(appearance.name, systemImage: appearance.symbol)
                        .font(.caption2)
                        .foregroundStyle(appearance.needsACall ? .red : .orange)
                }
            }
            Spacer()
            if let uf = treatment.ultrafiltration {
                Text("\(Int(uf))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(treatment.isNegativeUF ? .orange : .secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        if treatment.kind.isPeritoneal {
            var parts: [String] = []
            if !treatment.dextrose.isEmpty { parts.append(treatment.dextrose) }
            if treatment.fillML > 0 { parts.append("in \(Int(treatment.fillML))") }
            if treatment.drainML > 0 { parts.append("out \(Int(treatment.drainML))") }
            return parts.isEmpty ? treatment.kind.name : parts.joined(separator: " · ")
        }
        var parts: [String] = []
        if treatment.minutes > 0 { parts.append("\(treatment.minutes) min") }
        if treatment.ufAchievedML > 0 { parts.append("UF \(Int(treatment.ufAchievedML))") }
        return parts.isEmpty ? treatment.kind.name : parts.joined(separator: " · ")
    }
}

private struct DayRow: View {
    let day: DayRecord
    let prescription: Prescription?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !day.flags.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }
            if let uf = day.totalUF {
                Text("\(Int(uf)) mL")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(uf < 0 ? .orange : .secondary)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts: [String] = []
        let count = day.sortedTreatments.count
        if count > 0 { parts.append("\(count) \(count == 1 ? "entry" : "entries")") }
        if day.weightKg > 0 { parts.append("\(day.weightKg == day.weightKg.rounded() ? String(Int(day.weightKg)) : String(format: "%.1f", day.weightKg)) kg") }
        if day.systolic > 0 { parts.append("\(day.systolic)/\(day.diastolic)") }
        return parts.isEmpty ? "nothing recorded" : parts.joined(separator: " · ")
    }
}
