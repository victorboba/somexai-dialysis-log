import SwiftUI
import SwiftData

/// What the unit wrote down, typed in once.
///
/// Everything on this screen comes off a prescription the renal unit set. The app does not
/// suggest any of it, does not check it, and does not change it. Having it here means a new
/// exchange starts pre-filled with the usual, and the monthly sheet can print what was
/// prescribed next to what happened.
struct PrescriptionView: View {
    @Bindable var prescription: Prescription
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Modality", selection: $prescription.modality) {
                        ForEach(Modality.allCases) { Text($0.name).tag($0) }
                    }
                } header: {
                    Text("Treatment")
                } footer: {
                    Text("This decides which fields the rest of the app shows you, and nothing else.")
                }

                if prescription.modality.isPeritoneal {
                    Section {
                        Stepper("Exchanges a day: \(prescription.exchangesPerDay)",
                                value: $prescription.exchangesPerDay, in: 0...12)
                        Volume("Fill volume", value: $prescription.fillVolumeML)
                        Stepper(prescription.dwellMinutes == 0
                                ? "Dwell: not set"
                                : "Dwell: \(prescription.dwellMinutes) min",
                                value: $prescription.dwellMinutes, in: 0...1440, step: 15)
                        Picker("Usual dextrose", selection: $prescription.usualDextrose) {
                            ForEach(DextroseStrength.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                    } header: {
                        Text("As prescribed")
                    } footer: {
                        Text("Copy these from your prescription. A new exchange starts from them, so a normal one is a few taps.")
                    }

                    if prescription.modality == .apd {
                        Section("Cycler") {
                            Volume("Total volume", value: $prescription.cyclerTotalVolumeML)
                            Stepper("Cycles: \(prescription.cyclerCycles)",
                                    value: $prescription.cyclerCycles, in: 0...20)
                            Volume("Last fill", value: $prescription.lastFillVolumeML)
                        }
                    }
                } else {
                    Section("As prescribed") {
                        Stepper("Sessions a week: \(prescription.treatmentsPerWeek)",
                                value: $prescription.treatmentsPerWeek, in: 0...14)
                        Stepper(prescription.treatmentMinutes == 0
                                ? "Session length: not set"
                                : "Session length: \(prescription.treatmentMinutes) min",
                                value: $prescription.treatmentMinutes, in: 0...600, step: 15)
                        Number("Blood flow", value: $prescription.bloodFlowRate, unit: "mL/min")
                        Number("Dialysate flow", value: $prescription.dialysateFlowRate, unit: "mL/min")
                    }
                }

                Section {
                    Weight("Dry weight", value: $prescription.dryWeightKg)
                    Volume("Target fluid off per day", value: $prescription.targetDailyUFml)
                } header: {
                    Text("Targets your unit set")
                } footer: {
                    Text("Leave either blank if your unit has not given you a number. The app compares what happened against these; it never works out a target of its own.")
                }

                Section {
                    TextField("Unit or clinic", text: $prescription.unitName)
                    TextField("Phone", text: $prescription.unitPhone)
                        .keyboardType(.phonePad)
                    TextField("Nurse", text: $prescription.nurseName)
                } header: {
                    Text("Who to ring")
                } footer: {
                    Text("Put the number in. It turns into a call button on the exchange screen the moment you record a cloudy drain, which is when nobody can find it.")
                }

                Section("Notes") {
                    TextField("Anything else from your prescription",
                              text: $prescription.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Text("Dialysis Log is a diary. It records the prescription your renal unit set and what actually happened against it. It does not set or change a prescription, does not advise on treatment, and is not a medical device. Anything that worries you is a call to your unit, not a question for this app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("My prescription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }
                }
            }
        }
    }
}
