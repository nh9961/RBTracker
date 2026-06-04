import Charts
import SwiftUI
import UniformTypeIdentifiers

struct EntrySheet: Identifiable {
  let id = UUID()
  var entry: RedBullEntry?
  var draft: EntryDraft

  static func new() -> EntrySheet {
    EntrySheet(entry: nil, draft: EntryDraft())
  }

  static func edit(_ entry: RedBullEntry) -> EntrySheet {
    EntrySheet(entry: entry, draft: EntryDraft(entry: entry))
  }

  static func draft(_ draft: EntryDraft) -> EntrySheet {
    EntrySheet(entry: nil, draft: draft)
  }
}

struct MainView: View {
  @EnvironmentObject private var store: AppStore
  @State private var entrySheet: EntrySheet?
  @State private var scannerOpen = false
  @State private var resetConfirmationOpen = false
  @State private var exportDocument = JSONExportDocument()
  @State private var exportingJSON = false
  @State private var importingJSON = false

  var body: some View {
    TabView(selection: $store.activeView) {
      OverviewView(
        onAdd: { entrySheet = .new() },
        onScan: { scannerOpen = true },
        onOpenLogbook: { store.activeView = .logbook },
        onOpenSettings: { store.activeView = .settings }
      )
      .tag(AppView.overview)
      .tabItem { Label(AppView.overview.title, systemImage: AppView.overview.symbol) }

      LogbookView(
        onAdd: { entrySheet = .new() },
        onEdit: { entrySheet = .edit($0) }
      )
      .tag(AppView.logbook)
      .tabItem { Label(AppView.logbook.title, systemImage: AppView.logbook.symbol) }

      TrendsView()
        .tag(AppView.trends)
        .tabItem { Label(AppView.trends.title, systemImage: AppView.trends.symbol) }

      SettingsView(
        onExportJSON: exportJSON,
        onImportJSON: { importingJSON = true },
        onReset: { resetConfirmationOpen = true }
      )
      .tag(AppView.settings)
      .tabItem { Label(AppView.settings.title, systemImage: AppView.settings.symbol) }
    }
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
    .sheet(item: $entrySheet) { sheet in
      EntryEditorView(sheet: sheet) { draft in
        store.stageDraftForSave(draft, editingId: sheet.entry?.id)
        entrySheet = nil
      }
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $scannerOpen) {
      BarcodeScannerSheet { draft in
        scannerOpen = false
        store.stageDraftForSave(draft)
      } editBeforeAdding: { draft in
        scannerOpen = false
        entrySheet = .draft(draft)
      }
    }
    .sheet(isPresented: $store.setupOpen) {
      OnboardingView()
        .interactiveDismissDisabled(false)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    .fileExporter(
      isPresented: $exportingJSON,
      document: exportDocument,
      contentType: .json,
      defaultFilename: "red-bull-intake-\(DateFormatters.dateKey.string(from: Date())).json"
    ) { result in
      if case .failure(let error) = result {
        store.syncError = error.localizedDescription
      } else {
        store.notice = "JSON backup exported."
      }
    }
    // json in/out only — excel never made it to ios and i am not pretending otherwise.
    .fileImporter(isPresented: $importingJSON, allowedContentTypes: [.json]) { result in
      if case .success(let url) = result {
        Task { await store.importJSON(from: url) }
      } else if case .failure(let error) = result {
        store.syncError = error.localizedDescription
      }
    }
    .alert("Delete all entries?", isPresented: $resetConfirmationOpen) {
      Button("Cancel", role: .cancel) {}
      Button("Delete all", role: .destructive) {
        Task { await store.resetAll() }
      }
    } message: {
      Text("This removes every intake entry owned by the signed-in user.")
    }
    .alert("Over your limit?", isPresented: $store.showLimitOverride) {
      Button("Cancel", role: .cancel) {
        store.clearLimitOverride()
      }
      Button("Log anyway") {
        Task { await store.confirmLimitOverride() }
      }
    } message: {
      Text(store.limitOverrideMessage.isEmpty ? "This intake goes past one of your daily limits." : store.limitOverrideMessage)
    }
  }

  private func exportJSON() {
    do {
      exportDocument = try JSONExportDocument(entries: store.entries)
      exportingJSON = true
    } catch {
      store.syncError = error.localizedDescription
    }
  }
}

struct OverviewView: View {
  @EnvironmentObject private var store: AppStore
  var onAdd: () -> Void
  var onScan: () -> Void
  var onOpenLogbook: () -> Void
  var onOpenSettings: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 18) {
          StatusRail()
          TodayHero(onAdd: onAdd, onScan: onScan)
          QuickAddCarousel()
          TodayLimitsPanel(onOpenSettings: onOpenSettings)
          MetricCarousel()
          RecentEntriesPanel(onAdd: onAdd, onOpenLogbook: onOpenLogbook)
          FlavourSpectrumPanel()
          InsightStack()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
      }
      .liquidBackground(store.activeTheme)
      .navigationTitle("Today")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button(action: onScan) {
            Image(systemName: "barcode.viewfinder")
          }
          .glassButton()

          Button(action: onAdd) {
            Image(systemName: "plus")
          }
          .glassProminentButton()
        }
      }
      // pull to refresh because we still do not have proper realtime. shocking, i know.
      .refreshable {
        await store.refreshEntries()
      }
    }
  }
}

struct TodayHero: View {
  @EnvironmentObject private var store: AppStore
  var onAdd: () -> Void
  var onScan: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Hi \(firstName(store.user))")
            .font(.title2.weight(.semibold))
          Text(DateFormatters.humanDateTime.string(from: Date()))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text(userInitial(store.user))
          .font(.headline.weight(.bold))
          .foregroundStyle(.white)
          .frame(width: 42, height: 42)
          .background(store.activeTheme.primary, in: Circle())
      }

      HStack(alignment: .lastTextBaseline, spacing: 8) {
        Text(Metrics.one(store.limitCheck.todayCans))
          .font(.system(size: 64, weight: .bold, design: .rounded))
          .minimumScaleFactor(0.72)
        Text("cans")
          .font(.title3.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 10) {
        TodayStat(label: "Caffeine", value: store.dashboard.todayCaffeine, symbol: "waveform.path.ecg")
        TodayStat(label: "Sugar", value: store.dashboard.todaySugar, symbol: "cube.transparent")
        TodayStat(label: "Streak", value: "\(store.dashboard.currentStreak)d", symbol: "flame")
      }

      HStack(spacing: 12) {
        Button("Add", systemImage: "plus", action: onAdd)
          .frame(maxWidth: .infinity)
          .glassProminentButton()

        Button("Scan", systemImage: "barcode.viewfinder", action: onScan)
          .frame(maxWidth: .infinity)
          .glassButton()
      }
      .controlSize(.large)
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .liquidGlass(radius: 32, tint: store.activeTheme.primary)
  }
}

struct TodayStat: View {
  var label: String
  var value: String
  var symbol: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Image(systemName: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

struct QuickAddCarousel: View {
  @EnvironmentObject private var store: AppStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Quick Add")
        .font(.headline)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(quickAdds) { item in
            Button {
              store.quickAdd(item)
            } label: {
              VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "bolt.fill")
                  .font(.headline.weight(.semibold))
                  .foregroundStyle(Color(hex: flavourMeta(item.flavour).accent))
                  .frame(width: 34, height: 34)
                  .background(.thinMaterial, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                  Text("\(item.sizeMl)ml")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(14)
              .frame(width: 138, height: 126, alignment: .leading)
              .liquidGlass(radius: 24, tint: Color(hex: flavourMeta(item.flavour).accent))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 2)
      }
    }
  }
}

struct TodayLimitsPanel: View {
  @EnvironmentObject private var store: AppStore
  var onOpenSettings: () -> Void

  var body: some View {
    let limits = store.userLimits
    let check = store.limitCheck

    GlassSection(
      title: "Daily Limits",
      subtitle: limits.hasAnyLimit ? "BST totals" : "No limits set",
      symbol: "target",
      tint: store.activeTheme.secondary
    ) {
      if !limits.hasAnyLimit {
        Button("Set limits", systemImage: "slider.horizontal.3", action: onOpenSettings)
          .glassButton()
      } else {
        VStack(spacing: 14) {
          if let dailyCanLimit = limits.dailyCanLimit {
            LimitProgressRow(
              label: "Cans",
              value: "\(Metrics.one(check.todayCans)) / \(Metrics.one(dailyCanLimit))",
              progress: Limits.progress(current: check.todayCans, limit: dailyCanLimit),
              isOver: check.violations.contains(.cans)
            )
          }
          if let dailySpendLimit = limits.dailySpendLimit {
            LimitProgressRow(
              label: "Spend",
              value: "\(Metrics.money(check.todaySpend)) / \(Metrics.money(dailySpendLimit))",
              progress: Limits.progress(current: check.todaySpend, limit: dailySpendLimit),
              isOver: check.violations.contains(.spend)
            )
          }
          if let stopTime = limits.stopTime {
            Label(check.pastStopTime ? "Past \(Limits.stopTimeLabel(stopTime))" : "Stop by \(Limits.stopTimeLabel(stopTime))", systemImage: "clock")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(check.pastStopTime ? .red : .secondary)
          }
        }
      }
    }
  }
}

struct MetricCarousel: View {
  @EnvironmentObject private var store: AppStore

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        MetricTile(label: "This month", value: store.dashboard.monthCans, detail: store.dashboard.monthSpend, symbol: "calendar", color: store.activeTheme.primary)
        MetricTile(label: "All-time spend", value: store.dashboard.totalSpend, detail: "\(store.entries.count) entries", symbol: "sterlingsign.circle.fill", color: store.activeTheme.secondary)
        MetricTile(label: "Favourite", value: store.dashboard.favouriteFlavour, detail: "by cans", symbol: "heart.fill", color: .pink)
        MetricTile(label: "Days without", value: store.dashboard.daysWithoutRedBull, detail: "\(store.dashboard.currentStreak) day streak", symbol: "timer", color: .orange)
      }
      .padding(.vertical, 2)
    }
  }
}

struct RecentEntriesPanel: View {
  @EnvironmentObject private var store: AppStore
  var onAdd: () -> Void
  var onOpenLogbook: () -> Void

  var body: some View {
    GlassSection(title: "Recent", subtitle: "\(store.recentEntries.count) latest", symbol: "clock.arrow.circlepath", tint: store.activeTheme.primary) {
      if store.recentEntries.isEmpty {
        EmptyStateView(title: "Nothing logged", copy: "Your newest entries will appear here.", actionLabel: "Add intake", action: onAdd)
      } else {
        VStack(spacing: 10) {
          ForEach(store.recentEntries) { entry in
            EntryRowView(entry: entry, onEdit: onOpenLogbook) {
              Task { await store.deleteEntry(entry) }
            }
          }

          Button("Open logbook", systemImage: "chevron.right", action: onOpenLogbook)
            .glassButton()
        }
      }
    }
  }
}

struct FlavourSpectrumPanel: View {
  @EnvironmentObject private var store: AppStore

  var body: some View {
    GlassSection(title: "Flavours", subtitle: "Cans by flavour", symbol: "swatchpalette", tint: .pink) {
      if store.flavourData.isEmpty {
        EmptyStateView(title: "No flavours yet", copy: "Flavour mix appears after your first entry.", systemImage: "swatchpalette")
      } else {
        VStack(spacing: 12) {
          ForEach(store.flavourData.prefix(6)) { point in
            VStack(spacing: 7) {
              HStack {
                Circle()
                  .fill(Color(hex: point.accent))
                  .frame(width: 10, height: 10)
                Text(point.name)
                  .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Metrics.one(point.value))")
                  .font(.subheadline.weight(.semibold))
              }
              ProgressView(value: point.value / max(store.flavourData.first?.value ?? 1, 1))
                .tint(Color(hex: point.accent))
            }
          }
        }
      }
    }
  }
}

struct InsightStack: View {
  @EnvironmentObject private var store: AppStore

  var body: some View {
    if !store.insights.isEmpty {
      VStack(spacing: 10) {
        ForEach(store.insights.prefix(3)) { insight in
          InsightCard(insight: insight)
        }
      }
    }
  }
}

struct InsightCard: View {
  @EnvironmentObject private var store: AppStore
  var insight: Insight

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "sparkle.magnifyingglass")
        .font(.headline.weight(.semibold))
        .foregroundStyle(store.activeTheme.primary)
        .frame(width: 38, height: 38)
        .background(store.activeTheme.primary.opacity(0.12), in: Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text(insight.label)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(insight.value)
          .font(.headline)
        Text(insight.detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .liquidGlass(radius: 22, tint: store.activeTheme.primary)
  }
}

struct LogbookView: View {
  @EnvironmentObject private var store: AppStore
  var onAdd: () -> Void
  var onEdit: (RedBullEntry) -> Void

  var body: some View {
    NavigationStack {
      List {
        if !store.syncError.isEmpty || !store.setupStatus.isOK || store.busyAction != nil {
          Section {
            StatusRail()
              .listRowInsets(EdgeInsets())
              .listRowBackground(Color.clear)
          }
        }

        Section {
          FiltersCard()
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }

        Section {
          if store.entriesInView.isEmpty {
            EmptyStateView(title: "No entries found", copy: "Add an entry or clear the filters.", actionLabel: "Add intake", action: onAdd)
              .listRowBackground(Color.clear)
          } else {
            ForEach(store.entriesInView) { entry in
              EntryRowView(entry: entry, onEdit: { onEdit(entry) }) {
                Task { await store.deleteEntry(entry) }
              }
              .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
              .listRowSeparator(.hidden)
              .listRowBackground(Color.clear)
            }
          }
        } header: {
          Text("\(store.entriesInView.count) entries")
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .contentMargins(.horizontal, 20, for: .scrollContent)
      .liquidBackground(store.activeTheme)
      .navigationTitle("Logbook")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: onAdd) {
            Image(systemName: "plus")
          }
          .glassProminentButton()
        }
      }
      .refreshable {
        await store.refreshEntries()
      }
    }
  }
}

struct FiltersCard: View {
  @EnvironmentObject private var store: AppStore

  var body: some View {
    GlassSection(title: "Filters", symbol: "line.3.horizontal.decrease.circle", tint: store.activeTheme.secondary) {
      VStack(spacing: 14) {
        Picker("Flavour", selection: $store.filters.flavour) {
          Text("All flavours").tag("all")
          ForEach(store.allFlavours) { flavour in
            Text(flavour.name).tag(flavour.name)
          }
        }
        .pickerStyle(.menu)

        Picker("Date range", selection: $store.filters.dateRange) {
          ForEach(DateFilter.allCases) { filter in
            Text(filter.label).tag(filter)
          }
        }
        .pickerStyle(.segmented)

        if store.filters.dateRange == .custom {
          DatePicker("From", selection: $store.filters.from, displayedComponents: .date)
          DatePicker("To", selection: $store.filters.to, displayedComponents: .date)
        }

        TextField("Store or location", text: $store.filters.store)
          .textFieldStyle(.roundedBorder)

        Button("Clear filters", systemImage: "xmark") {
          store.filters = EntryFilters()
        }
        .glassButton()
      }
    }
  }
}

struct TrendsView: View {
  @EnvironmentObject private var store: AppStore
  @State private var projectionDays = 30

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 18) {
          StatusRail()
          FiltersCard()

          TrendChartCard(title: "Cans and Spend", subtitle: "Last 30 logged days", symbol: "chart.xyaxis.line") {
            if store.chartData.isEmpty {
              EmptyStateView(title: "No trend data", copy: "Filtered chart data appears here.")
            } else {
              Chart(store.chartData) { point in
                BarMark(x: .value("Day", point.label), y: .value("Cans", point.cans))
                  .foregroundStyle(Color.red.opacity(0.36))
                LineMark(x: .value("Day", point.label), y: .value("Spend", point.spend))
                  .foregroundStyle(store.activeTheme.primary)
              }
              .frame(height: 240)
            }
          }

          TrendChartCard(title: "Caffeine", subtitle: "Estimated mg", symbol: "waveform.path.ecg") {
            if store.chartData.isEmpty {
              EmptyStateView(title: "No caffeine data", copy: "Add entries to estimate caffeine over time.")
            } else {
              Chart(store.chartData) { point in
                BarMark(x: .value("Day", point.label), y: .value("Caffeine", point.caffeine))
                  .foregroundStyle(store.activeTheme.secondary)
              }
              .frame(height: 220)
            }
          }

          TrendChartCard(title: "Weekly", subtitle: "Spend and cans", symbol: "calendar.badge.clock") {
            if store.weekData.isEmpty {
              EmptyStateView(title: "No weekly comparison", copy: "Weekly comparisons appear as your history grows.")
            } else {
              Chart(store.weekData) { point in
                LineMark(x: .value("Week", point.label), y: .value("Spend", point.spend))
                  .foregroundStyle(store.activeTheme.primary)
                LineMark(x: .value("Week", point.label), y: .value("Cans", point.cans))
                  .foregroundStyle(.orange)
              }
              .frame(height: 220)
            }
          }

          TrendChartCard(title: "Flavour Split", subtitle: "Cans by flavour", symbol: "swatchpalette") {
            if store.flavourData.isEmpty {
              EmptyStateView(title: "No flavour split", copy: "Entries will form a flavour mix here.")
            } else {
              Chart(store.flavourData.prefix(10)) { point in
                BarMark(x: .value("Cans", point.value), y: .value("Flavour", point.name))
                  .foregroundStyle(Color(hex: point.accent))
              }
              .frame(height: 260)
            }
          }

          SpendForecastCard(projectionDays: $projectionDays)
          InsightStack()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
      }
      .liquidBackground(store.activeTheme)
      .navigationTitle("Trends")
      .refreshable {
        await store.refreshEntries()
      }
    }
  }
}

struct TrendChartCard<Content: View>: View {
  @EnvironmentObject private var store: AppStore
  var title: String
  var subtitle: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    GlassSection(title: title, subtitle: subtitle, symbol: symbol, tint: store.activeTheme.primary) {
      content
    }
  }
}

struct SpendForecastCard: View {
  @EnvironmentObject private var store: AppStore
  @Binding var projectionDays: Int

  var body: some View {
    GlassSection(title: "Spend Forecast", subtitle: forecastSubtitle, symbol: "sterlingsign.arrow.circlepath", tint: .green) {
      if !stats.hasData {
        EmptyStateView(title: "No spend forecast yet", copy: "Add an intake first.")
      } else {
        VStack(spacing: 16) {
          Picker("Forecast window", selection: $projectionDays) {
            Text("7d").tag(7)
            Text("30d").tag(30)
            Text("90d").tag(90)
            Text("1y").tag(365)
          }
          .pickerStyle(.segmented)

          HStack(spacing: 10) {
            ForecastStat(label: "Projected", value: Metrics.money(projectedSpend), note: "\(Metrics.one(projectedCans)) cans")
            ForecastStat(label: "20% lower", value: Metrics.money(projectedSpend * 0.8), note: "\(Metrics.one(projectedCans * 0.8)) cans")
          }

          Chart(forecastPoints) { point in
            LineMark(x: .value("Day", point.day), y: .value("Current", point.current))
              .foregroundStyle(store.activeTheme.primary)
            LineMark(x: .value("Day", point.day), y: .value("Lower", point.lower))
              .foregroundStyle(.green)
              .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            if let limit = point.limit {
              LineMark(x: .value("Day", point.day), y: .value("Limit", limit))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
          }
          .frame(height: 220)

          Button("Use 20% lower limit", systemImage: "target") {
            Task {
              var limits = store.userLimits
              limits.dailySpendLimit = round(stats.avgDailySpend * 0.8 * 100) / 100
              await store.saveUserLimits(limits)
            }
          }
          .glassButton()
        }
      }
    }
  }

  private var activePeriodDays: Double {
    guard let first = store.entries.compactMap({ DateCodec.date(from: $0.dateTime) }).min() else {
      return 1
    }
    return max(1, ceil(Date().timeIntervalSince(first) / 86_400))
  }

  private var stats: (hasData: Bool, avgDailySpend: Double, avgDailyCans: Double) {
    let periodStart = Date().addingTimeInterval(-activePeriodDays * 86_400)
    let recent = Metrics.entriesInRange(store.entries, start: periodStart, end: Date())
    guard !recent.isEmpty else { return (false, 0, 0) }
    return (
      true,
      Metrics.sum(recent, Metrics.spend) / activePeriodDays,
      Metrics.sum(recent, \.cans) / activePeriodDays
    )
  }

  private var projectedSpend: Double {
    stats.avgDailySpend * Double(projectionDays)
  }

  private var projectedCans: Double {
    stats.avgDailyCans * Double(projectionDays)
  }

  private var forecastSubtitle: String {
    stats.hasData ? "\(Int(activePeriodDays)) day average: \(Metrics.money(stats.avgDailySpend)) per day" : "Based on past spending"
  }

  private var forecastPoints: [ForecastPoint] {
    (1...projectionDays).map { day in
      ForecastPoint(
        day: day,
        current: Double(day) * stats.avgDailySpend,
        lower: Double(day) * stats.avgDailySpend * 0.8,
        limit: store.userLimits.dailySpendLimit.map { Double(day) * $0 }
      )
    }
  }
}

struct ForecastPoint: Identifiable {
  var id: Int { day }
  var day: Int
  var current: Double
  var lower: Double
  var limit: Double?
}

struct ForecastStat: View {
  var label: String
  var value: String
  var note: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.headline)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(note)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: AppStore
  var onExportJSON: () -> Void
  var onImportJSON: () -> Void
  var onReset: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        if !store.syncError.isEmpty || !store.setupStatus.isOK || store.busyAction != nil {
          Section {
            StatusRail()
              .listRowBackground(Color.clear)
          }
        }

        Section("Daily Limits") {
          LimitsSettingsEditor()
        }

        Section("Appearance") {
          ThemePickerGrid()
            .padding(.vertical, 6)
        }

        Section {
          Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
            Task { await store.refreshEntries() }
          }
          Button("Export JSON", systemImage: "doc.badge.arrow.up", action: onExportJSON)
            .disabled(store.entries.isEmpty)
          Button("Import JSON", systemImage: "square.and.arrow.down", action: onImportJSON)
          Button("Delete all", systemImage: "trash", role: .destructive, action: onReset)
            .disabled(store.entries.isEmpty)
        } header: {
          Text("Data")
        } footer: {
          Text("\(store.entries.count) entries synced for this account.")
        }

        Section("Account") {
          HStack(spacing: 12) {
            Text(userInitial(store.user))
              .font(.headline.weight(.bold))
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .background(store.activeTheme.primary, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
              Text(accountDisplayName)
                .font(.headline)
              Text(store.user?.email ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }

          Button("Run setup again", systemImage: "sparkles") {
            store.setupOpen = true
          }

          Button("Log out", systemImage: "rectangle.portrait.and.arrow.right") {
            Task { await store.logout() }
          }
        }

        Section("Backend") {
          Text("Set your own backend ids in AppConfig.plist before shipping this.")
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .liquidBackground(store.activeTheme)
      .navigationTitle("Settings")
    }
  }

  private var accountDisplayName: String {
    guard let user = store.user else { return "Appwrite user" }
    return user.name.isEmpty ? "Appwrite user" : user.name
  }
}

struct ThemePickerGrid: View {
  @EnvironmentObject private var store: AppStore

  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
      ForEach(appThemes) { theme in
        Button {
          store.setThemeId(theme.id)
        } label: {
          HStack(spacing: 10) {
            Circle()
              .fill(theme.swatch)
              .frame(width: 22, height: 22)
            Text(theme.label)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
            Spacer()
            if store.themeId == theme.id {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.primary)
            }
          }
          .padding(12)
          .background(store.themeId == theme.id ? theme.primary.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct LimitsSettingsEditor: View {
  @EnvironmentObject private var store: AppStore
  @State private var canInput = ""
  @State private var spendInput = ""
  @State private var stopInput = Date()
  @State private var stopEnabled = false

  var body: some View {
    VStack(spacing: 12) {
      TextField("Cans per day", text: $canInput)
        .keyboardType(.decimalPad)
      TextField("Spend per day", text: $spendInput)
        .keyboardType(.decimalPad)
      Toggle("Stop drinking by", isOn: $stopEnabled)
      if stopEnabled {
        DatePicker("Stop time", selection: $stopInput, displayedComponents: .hourAndMinute)
      }
      if store.userLimits.hasAnyLimit {
        LabeledContent("Today") {
          Text("\(Metrics.one(store.limitCheck.todayCans)) cans, \(Metrics.money(store.limitCheck.todaySpend))")
        }
      }
      Button("Save limits", systemImage: "target") {
        Task {
          var limits = UserLimits()
          if let can = Double(canInput.trimmingCharacters(in: .whitespacesAndNewlines)), can > 0 {
            limits.dailyCanLimit = max(0.25, can)
          }
          if let spend = Double(spendInput.trimmingCharacters(in: .whitespacesAndNewlines)), spend >= 0 {
            limits.dailySpendLimit = max(0, spend)
          }
          if stopEnabled {
            limits.stopTime = DateFormatters.bstTime.string(from: stopInput)
          }
          await store.saveUserLimits(limits)
        }
      }
      .glassProminentButton()
      .frame(maxWidth: .infinity)
    }
    .onAppear(perform: loadValues)
    .onChange(of: store.userLimits) { _, _ in loadValues() }
  }

  private func loadValues() {
    canInput = store.userLimits.dailyCanLimit.map(Metrics.one) ?? ""
    spendInput = store.userLimits.dailySpendLimit.map { String(format: "%.2f", $0) } ?? ""
    if let stop = store.userLimits.stopTime {
      stopEnabled = true
      let parts = stop.split(separator: ":").compactMap { Int(String($0)) }
      if parts.count == 2 {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = parts[0]
        components.minute = parts[1]
        stopInput = Calendar.current.date(from: components) ?? Date()
      }
    } else {
      stopEnabled = false
    }
  }
}
