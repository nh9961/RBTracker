import SwiftUI

struct OnboardingView: View {
  @EnvironmentObject private var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @State private var step = 1
  @State private var dailyCanLimit: Double? = 2
  @State private var dailySpendLimit: Double? = 3.5
  @State private var stopTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
  @State private var stopEnabled = true
  @State private var selectedThemeId: String = defaultThemeId

  private let stepCount = 6

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        VStack(spacing: 10) {
          HStack {
            Text("Setup")
              .font(.title2.weight(.semibold))
            Spacer()
            Text("\(step) of \(stepCount)")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          }
          ProgressView(value: Double(step), total: Double(stepCount))
            .tint(appTheme(selectedThemeId).primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)

        TabView(selection: $step) {
          welcomeStep.tag(1)
          themeStep.tag(2)
          canStep.tag(3)
          spendStep.tag(4)
          stopStep.tag(5)
          finishStep.tag(6)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        HStack {
          Button("Back", systemImage: "chevron.left") {
            step = max(1, step - 1)
          }
          .glassButton()
          .disabled(step == 1)

          Spacer()

          if step < stepCount {
            Button("Continue", systemImage: "chevron.right") {
              step = min(stepCount, step + 1)
            }
            .glassProminentButton()
          } else {
            // limits and theme land in appwrite prefs, not some mystery local plist.
            Button("Save setup", systemImage: "checkmark") {
              Task {
                await store.saveOnboarding(limits: limits, onboardingThemeId: selectedThemeId)
                dismiss()
              }
            }
            .glassProminentButton()
            .disabled(store.busyAction == "save-onboarding")
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
      }
      .liquidBackground(appTheme(selectedThemeId))
      .navigationTitle("Welcome")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }
      }
      .onAppear {
        selectedThemeId = store.themeId
      }
    }
  }

  private var welcomeStep: some View {
    OnboardingPanel {
      Text("Hey \(firstName(store.user)). Set your baseline.")
        .font(.system(size: 38, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.65)
      Text("Pick a theme, then set optional limits for cans, spend, and time. You can change all of this later.")
        .font(.body)
        .foregroundStyle(.secondary)
    }
  }

  private var themeStep: some View {
    OnboardingPanel {
      Text("Choose the app color.")
        .font(.largeTitle.weight(.bold))
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        ForEach(appThemes) { theme in
          Button {
            selectedThemeId = theme.id
            store.setThemeId(theme.id, sync: false)
          } label: {
            HStack {
              Circle().fill(theme.swatch).frame(width: 24, height: 24)
              Text(theme.label)
              Spacer()
              if selectedThemeId == theme.id {
                Image(systemName: "checkmark")
              }
            }
            .padding()
            .background(selectedThemeId == theme.id ? theme.primary.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var canStep: some View {
    OnboardingPanel {
      Text("What is your daily can ceiling?")
        .font(.largeTitle.weight(.bold))
      Stepper(value: Binding(
        get: { dailyCanLimit ?? 0 },
        set: { dailyCanLimit = $0 <= 0 ? nil : $0 }
      ), in: 0...10, step: 0.5) {
        Text(dailyCanLimit.map { "\(Metrics.one($0)) cans per day" } ?? "No daily cap")
          .font(.title2.weight(.semibold))
      }
      Button(dailyCanLimit == nil ? "Use 2 cans" : "No daily cap") {
        dailyCanLimit = dailyCanLimit == nil ? 2 : nil
      }
      .glassButton()
    }
  }

  private var spendStep: some View {
    OnboardingPanel {
      Text("Set a daily spend cap.")
        .font(.largeTitle.weight(.bold))
      Stepper(value: Binding(
        get: { dailySpendLimit ?? 0 },
        set: { dailySpendLimit = $0 <= 0 ? nil : $0 }
      ), in: 0...30, step: 0.5) {
        Text(dailySpendLimit.map { "\(Metrics.money($0)) per day" } ?? "No spend cap")
          .font(.title2.weight(.semibold))
      }
      Button(dailySpendLimit == nil ? "Use \(Metrics.money(3.5))" : "No spend cap") {
        dailySpendLimit = dailySpendLimit == nil ? 3.5 : nil
      }
      .glassButton()
    }
  }

  private var stopStep: some View {
    OnboardingPanel {
      Text("Pick a stop time.")
        .font(.largeTitle.weight(.bold))
      Toggle("Enable stop-time warning", isOn: $stopEnabled)
      if stopEnabled {
        DatePicker("Stop by", selection: $stopTime, displayedComponents: .hourAndMinute)
      }
      Text("The web app checks this using Europe/London time. This native app keeps the same rule.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  private var finishStep: some View {
    OnboardingPanel {
      Text("Ready.")
        .font(.system(size: 52, weight: .bold, design: .rounded))
      VStack(alignment: .leading, spacing: 8) {
        Label(dailyCanLimit.map { "\(Metrics.one($0)) cans/day" } ?? "No can cap", systemImage: "bolt.fill")
        Label(dailySpendLimit.map { "\(Metrics.money($0))/day" } ?? "No spend cap", systemImage: "sterlingsign.circle.fill")
        Label(stopEnabled ? "Stop by \(DateFormatters.clock.string(from: stopTime))" : "No stop time", systemImage: "clock.fill")
        Label("\(appTheme(selectedThemeId).label) theme", systemImage: "paintpalette.fill")
      }
      .font(.headline)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var limits: UserLimits {
    var limits = UserLimits()
    limits.dailyCanLimit = dailyCanLimit
    limits.dailySpendLimit = dailySpendLimit
    if stopEnabled {
      limits.stopTime = DateFormatters.bstTime.string(from: stopTime)
    }
    return limits
  }
}

struct OnboardingPanel<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      Spacer()
      content
      Spacer()
    }
    .padding(24)
    .frame(maxWidth: 560, maxHeight: .infinity, alignment: .leading)
    .liquidGlass(radius: 34)
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
  }
}
