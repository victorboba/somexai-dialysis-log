import SwiftUI
import SwiftData

/// One exchange, or one session.
///
/// Written for someone doing this four times a day while tired: the fields are in the order
/// the bags are handled, the prescribed values are pre-filled so a normal exchange is three
/// taps, and the fluid removed is worked out as you type rather than in your head at the
/// drain bag.
struct TreatmentEditorView: View {
    var treatment: Treatment?
    var day: DayRecord?
    let prescription: Prescription?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var time = Date()
    @State private var kind: TreatmentKind = .manualExchange
    @State private var dextrose = ""
    @State private var fillML: Double = 0
    @State private var drainML: Double = 0
    @State private var dwellMinutes: Int = 0
    @State private var appearance: EffluentAppearance = .clear
    @State private var minutes: Int = 0
    @State private var bloodFlowRate: Int = 0
    @State private var dialysateFlowRate: Int = 0
    @State private var ufGoalML: Double = 0
    @State private var ufAchievedML: Double = 0
    @State private var preWeightKg: Double = 0
    @State private var postWeightKg: Double = 0
    @State private var notes = ""

    private var modality: Modality { prescription?.modality ?? .capd }

    /// Worked out live from the two numbers on screen, so nobody subtracts in their head.
    private var ultrafiltration: Double? {
        guard fillML > 0, drainML > 0 else { return nil }
        return drainML - fillML
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: [.hourAndMinute])
                    if TreatmentKind.kinds(for: modality).count > 1 {
                        Picker("Kind", selection: $kind) {
                            ForEach(TreatmentKind.kinds(for: modality)) { Text($0.name).tag($0) }
                        }
                    }
                }

                if kind.isPeritoneal {
                    Section {
                        Picker("Dextrose", selection: $dextrose) {
                            ForEach(DextroseStrength.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                        Volume("Filled", value: $fillML)
                        Volume("Drained", value: $drainML)
                        Stepper(dwellMinutes == 0 ? "Dwell: not recorded" : "Dwell: \(dwellMinutes) min",
                                value: $dwellMinutes, in: 0...1440, step: 15)
                    } header: {
                        Text("The exchange")
                    } footer: {
                        if let uf = ultrafiltration {
                            Text(uf >= 0
                                 ? "That is \(Int(uf)) mL off."
                                 : "That is \(Int(-uf)) mL more in than out. It happens; your unit will want to know if it keeps happening.")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(uf < 0 ? .orange : .primary)
                        } else {
                            Text("Fill and drain both need a number before the fluid removed can be worked out. The app will not guess the missing one.")
                        }
                    }

                    Section {
                        ChoiceChips(options: EffluentAppearance.allCases,
                                    selection: $appearance,
                                    title: \.name,
                                    tint: { $0.needsACall ? .red : ($0 == .clear ? .green : .orange) })
                        if let advice = appearance.advice {
                            Label(advice, systemImage: appearance.symbol)
                                .font(.callout)
                                .foregroundStyle(appearance.needsACall ? .red : .orange)
                        }
                        if appearance.needsACall, let phone = prescription?.unitPhone, !phone.isEmpty,
                           let url = URL(string: "tel://\(phone.filter { $0.isNumber || $0 == "+" })") {
                            Link(destination: url) {
                                Label("Ring \(prescription?.unitName ?? "your unit")", systemImage: "phone.fill")
                            }
                        }
                    } header: {
                        Text("How it looked")
                    }
                } else {
                    Section("The session") {
                        Stepper(minutes == 0 ? "Time: not recorded" : "Time: \(minutes) min",
                                value: $minutes, in: 0...600, step: 15)
                        Number("Blood flow", value: $bloodFlowRate, unit: "mL/min")
                        Number("Dialysate flow", value: $dialysateFlowRate, unit: "mL/min")
                        Volume("UF goal", value: $ufGoalML)
                        Volume("UF achieved", value: $ufAchievedML)
                    }
                    Section("Weight and pressure") {
                        Weight("Before", value: $preWeightKg)
                        Weight("After", value: $postWeightKg)
                    }
                }

                Section("Notes") {
                    TextField("Anything worth telling the unit", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(treatment == nil ? "New \(kind.isPeritoneal ? "exchange" : "session")" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let t = treatment {
            time = t.time; kind = t.kind; dextrose = t.dextrose
            fillML = t.fillML; drainML = t.drainML; dwellMinutes = t.dwellMinutes
            appearance = t.appearance ?? .clear
            minutes = t.minutes; bloodFlowRate = t.bloodFlowRate
            dialysateFlowRate = t.dialysateFlowRate
            ufGoalML = t.ufGoalML; ufAchievedML = t.ufAchievedML
            preWeightKg = t.preWeightKg; postWeightKg = t.postWeightKg
            notes = t.notes
            return
        }
        // A new entry starts from the prescription, because most exchanges are the prescribed
        // one and retyping it four times a day is how people stop logging.
        kind = TreatmentKind.kinds(for: modality).first ?? .manualExchange
        if let p = prescription {
            dextrose = p.usualDextrose.isEmpty ? DextroseStrength.medium.rawValue : p.usualDextrose
            fillML = p.fillVolumeML
            dwellMinutes = p.dwellMinutes
            minutes = p.treatmentMinutes
            bloodFlowRate = p.bloodFlowRate
            dialysateFlowRate = p.dialysateFlowRate
        } else {
            dextrose = DextroseStrength.medium.rawValue
        }
    }

    private func save() {
        let record = treatment ?? Treatment(time: time, kind: kind)
        record.time = time; record.kind = kind
        record.dextrose = dextrose
        record.fillML = fillML; record.drainML = drainML
        record.dwellMinutes = dwellMinutes
        record.appearance = kind.isPeritoneal ? appearance : nil
        record.minutes = minutes
        record.bloodFlowRate = bloodFlowRate
        record.dialysateFlowRate = dialysateFlowRate
        record.ufGoalML = ufGoalML; record.ufAchievedML = ufAchievedML
        record.preWeightKg = preWeightKg; record.postWeightKg = postWeightKg
        record.notes = notes
        if treatment == nil {
            record.day = day
            context.insert(record)
        }
        try? context.save()
        let days = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        WidgetSync.update(with: days, prescription: prescription)
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}

/// The day's own numbers: the ones the nurse asks for at the visit.
struct DayEditorView: View {
    @Bindable var day: DayRecord
    let prescription: Prescription?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $day.date, displayedComponents: .date)
                    Weight("Weight", value: $day.weightKg)
                    if let dry = prescription?.dryWeightKg, dry > 0, day.weightKg > 0 {
                        let difference = day.weightKg - dry
                        Text(abs(difference) < 0.05
                             ? "That is your dry weight."
                             : String(format: "%@ %.1f kg %@ the %.1f kg dry weight your unit set",
                                      difference > 0 ? "That is" : "That is",
                                      abs(difference), difference > 0 ? "above" : "below", dry))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Weight")
                } footer: {
                    Text("Weigh at the same point each day — units usually say first thing, after the overnight drain.")
                }

                Section("Blood pressure") {
                    Number("Systolic", value: $day.systolic, unit: "mmHg")
                    Number("Diastolic", value: $day.diastolic, unit: "mmHg")
                    Number("Pulse", value: $day.pulse, unit: "bpm")
                }

                Section {
                    Temperature("Temperature", value: $day.temperatureC)
                } footer: {
                    Text("Worth recording if you feel unwell, and worth telling your unit about alongside anything you noticed in the drain.")
                }

                Section("How you felt") {
                    TextField("Swelling, breathlessness, exit site, anything else",
                              text: $day.symptoms, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Notes") {
                    TextField("Anything else", text: $day.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(day.date.formatted(.dateTime.weekday(.wide).day().month()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }
                }
            }
        }
    }
}

// MARK: - Small typed fields

struct Volume: View {
    let title: String
    @Binding var value: Double

    init(_ title: String, value: Binding<Double>) { self.title = title; self._value = value }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("—", value: $value, format: .number)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                Text("mL").foregroundStyle(.secondary)
            }
        }
    }
}

struct Weight: View {
    let title: String
    @Binding var value: Double

    init(_ title: String, value: Binding<Double>) { self.title = title; self._value = value }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("—", value: $value, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                Text("kg").foregroundStyle(.secondary)
            }
        }
    }
}

struct Temperature: View {
    let title: String
    @Binding var value: Double

    init(_ title: String, value: Binding<Double>) { self.title = title; self._value = value }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("—", value: $value, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                Text("°C").foregroundStyle(.secondary)
            }
        }
    }
}

struct Number: View {
    let title: String
    @Binding var value: Int
    let unit: String

    init(_ title: String, value: Binding<Int>, unit: String) {
        self.title = title; self._value = value; self.unit = unit
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("—", value: $value, format: .number)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}
