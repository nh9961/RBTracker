import SwiftUI

struct EntryEditorView: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  var sheet: EntrySheet
  var onSave: (EntryDraft) -> Void

  @State private var cans: String
  @State private var pricePerCan: String
  @State private var selectedFlavour: String
  @State private var customFlavour: String
  @State private var customAccent: String
  @State private var sizePreset: String
  @State private var customSize: String
  @State private var caffeineOverride: String
  @State private var date: Date
  @State private var storeName: String
  @State private var notes: String
  @State private var sugarFree: Bool

  init(sheet: EntrySheet, onSave: @escaping (EntryDraft) -> Void) {
    self.sheet = sheet
    self.onSave = onSave
    let draft = sheet.draft
    let isCustomFlavour = !builtInFlavours.contains(where: { $0.name == draft.flavour })
    _cans = State(initialValue: Metrics.one(draft.cans))
    _pricePerCan = State(initialValue: String(format: "%.2f", draft.pricePerCan))
    _selectedFlavour = State(initialValue: isCustomFlavour ? "Other" : draft.flavour)
    _customFlavour = State(initialValue: isCustomFlavour ? draft.flavour : "")
    _customAccent = State(initialValue: draft.flavourAccent.isEmpty ? "#b85d84" : draft.flavourAccent)
    _sizePreset = State(initialValue: Self.sizePreset(for: draft.sizeMl))
    _customSize = State(initialValue: "\(draft.sizeMl)")
    _caffeineOverride = State(initialValue: draft.caffeineMgPerCan.map { Metrics.one($0) } ?? "")
    _date = State(initialValue: draft.date)
    _storeName = State(initialValue: draft.store)
    _notes = State(initialValue: draft.notes)
    _sugarFree = State(initialValue: draft.sugarFree)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Drink") {
          TextField("Number of cans", text: $cans)
            .keyboardType(.decimalPad)
          TextField("Price per can", text: $pricePerCan)
            .keyboardType(.decimalPad)

          Picker("Flavour", selection: $selectedFlavour) {
            ForEach(store.allFlavours) { flavour in
              Text(flavour.name).tag(flavour.name)
            }
          }
          .onChange(of: selectedFlavour) { _, newValue in
            guard newValue != "Other" else { return }
            let meta = flavourMeta(newValue)
            customAccent = meta.accent
            sugarFree = meta.sugarFree
          }

          if selectedFlavour == "Other" {
            TextField("Custom flavour", text: $customFlavour)
            TextField("Accent hex", text: $customAccent)
              .textInputAutocapitalization(.never)
          }

          Picker("Can size", selection: $sizePreset) {
            Text("250ml").tag("250")
            Text("355ml").tag("355")
            Text("473ml").tag("473")
            Text("Custom").tag("custom")
          }
          .onChange(of: sizePreset) { _, newValue in
            guard newValue != "custom", let size = Int(newValue) else { return }
            customSize = newValue
            pricePerCan = String(format: "%.2f", Metrics.defaultPrice(for: size))
            caffeineOverride = ""
          }

          if sizePreset == "custom" {
            TextField("Custom size in ml", text: $customSize)
              .keyboardType(.numberPad)
          }

          TextField("Caffeine override mg/can", text: $caffeineOverride)
            .keyboardType(.decimalPad)

          Toggle("Count as sugar-free / zero sugar", isOn: $sugarFree)
        }

        Section("When") {
          DatePicker("Date and time", selection: $date)
        }

        Section("Context") {
          TextField("Location or store", text: $storeName)
          TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(3...6)
        }

        Section("Preview") {
          LabeledContent("Caffeine per can") {
            Text("\(Metrics.whole(caffeinePreview))mg")
              .fontWeight(.semibold)
          }
          LabeledContent("Estimated spend") {
            Text(Metrics.money((Double(cans) ?? 1) * (Double(pricePerCan) ?? 0)))
              .fontWeight(.semibold)
          }
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .liquidBackground(store.activeTheme)
      .navigationTitle(sheet.entry == nil ? "Add intake" : "Edit entry")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(sheet.entry == nil ? "Log" : "Save") {
            onSave(makeDraft())
          }
          .disabled(!isValid)
        }
      }
    }
  }

  private var isValid: Bool {
    (Double(cans) ?? 0) > 0 &&
      (Double(pricePerCan) ?? -1) >= 0 &&
      numericSize > 0 &&
      !finalFlavour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var numericSize: Int {
    if sizePreset == "custom" {
      return max(1, Int(customSize) ?? 250)
    }
    return Int(sizePreset) ?? 250
  }

  private var finalFlavour: String {
    selectedFlavour == "Other" ? (customFlavour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Other" : customFlavour) : selectedFlavour
  }

  private var caffeinePreview: Double {
    Metrics.caffeinePerCan(sizeMl: numericSize, override: Double(caffeineOverride))
  }

  // strings in, typed draft out — half the form is text fields so this is where the mess gets cleaned up.
  private func makeDraft() -> EntryDraft {
    let meta = flavourMeta(finalFlavour)
    var draft = EntryDraft()
    draft.cans = max(0.25, Double(cans) ?? 1)
    draft.flavour = finalFlavour
    draft.flavourAccent = selectedFlavour == "Other" ? (customAccent.isEmpty ? accentForCustomFlavour(finalFlavour) : customAccent) : meta.accent
    draft.sizeMl = numericSize
    draft.pricePerCan = max(0, Double(pricePerCan) ?? 0)
    draft.date = date
    draft.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.store = storeName.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.sugarFree = sugarFree || meta.sugarFree
    draft.caffeineMgPerCan = Double(caffeineOverride)
    draft.source = sheet.entry?.source ?? sheet.draft.source
    return draft
  }

  private static func sizePreset(for size: Int) -> String {
    [250, 355, 473].contains(size) ? "\(size)" : "custom"
  }
}
