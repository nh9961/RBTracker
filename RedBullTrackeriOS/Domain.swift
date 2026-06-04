import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum AppView: String, CaseIterable, Identifiable {
  case overview
  case logbook
  case trends
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .overview: "Overview"
    case .logbook: "Logbook"
    case .trends: "Trends"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .overview: "house.fill"
    case .logbook: "calendar"
    case .trends: "chart.line.uptrend.xyaxis"
    case .settings: "gearshape.fill"
    }
  }
}

enum EntrySource: String, Codable, CaseIterable {
  case manual
  case quickAdd = "quick-add"
  case excel
  case json
}

struct RedBullEntry: Identifiable, Codable, Equatable {
  var id: String
  var userId: String
  var cans: Double
  var flavour: String
  var flavourAccent: String
  var sizeMl: Int
  var pricePerCan: Double
  var dateTime: String
  var notes: String
  var store: String
  var sugarFree: Bool
  var caffeineMgPerCan: Double?
  var importKey: String
  var source: EntrySource
  var createdAt: String?
  var updatedAt: String?
}

struct EntryDraft: Equatable {
  var cans: Double = 1
  var flavour: String = defaultFlavour.name
  var flavourAccent: String = defaultFlavour.accent
  var sizeMl: Int = 250
  var pricePerCan: Double = 1.75
  var date: Date = Date()
  var notes: String = ""
  var store: String = ""
  var sugarFree: Bool = false
  var caffeineMgPerCan: Double?
  var source: EntrySource = .manual

  init() {}

  init(entry: RedBullEntry) {
    cans = entry.cans
    flavour = entry.flavour
    flavourAccent = entry.flavourAccent
    sizeMl = entry.sizeMl
    pricePerCan = entry.pricePerCan
    date = DateCodec.date(from: entry.dateTime) ?? Date()
    notes = entry.notes
    store = entry.store
    sugarFree = entry.sugarFree
    caffeineMgPerCan = entry.caffeineMgPerCan
    source = entry.source
  }
}

struct Flavour: Identifiable, Hashable, Codable {
  var id: String { name }
  var name: String
  var accent: String
  var sugarFree: Bool

  init(name: String, accent: String, sugarFree: Bool = false) {
    self.name = name
    self.accent = accent
    self.sugarFree = sugarFree
  }
}

let builtInFlavours: [Flavour] = [
  Flavour(name: "Original", accent: "#00A7FF"),
  Flavour(name: "Sugar Free", accent: "#E7EEF8", sugarFree: true),
  Flavour(name: "Ruby", accent: "#C3093B"),
  Flavour(name: "Iced Vanilla", accent: "#49adbe"),
  Flavour(name: "Tropical", accent: "#FFC247"),
  Flavour(name: "Watermelon", accent: "#FF355E"),
  Flavour(name: "Blueberry", accent: "#496DFF"),
  Flavour(name: "Coconut Berry", accent: "#D8F9FF"),
  Flavour(name: "Peach", accent: "#FF9B63"),
  Flavour(name: "Juneberry", accent: "#9C73FF"),
  Flavour(name: "Dragon Fruit", accent: "#FF3DBD"),
  Flavour(name: "Curuba Elderflower", accent: "#B7FF4A"),
  Flavour(name: "Winter Edition", accent: "#7CE7FF"),
  Flavour(name: "Summer Edition", accent: "#f0e53b"),
  Flavour(name: "Other", accent: "#AEB9C7"),
]

let defaultFlavour = builtInFlavours[0]

let fallbackAccents = [
  "#00F2FF",
  "#FF2C38",
  "#FFC247",
  "#B7FF4A",
  "#FF73D1",
  "#AEB9C7",
  "#7CE7FF",
  "#FF9B63",
]

func flavourMeta(_ name: String) -> Flavour {
  if let match = builtInFlavours.first(where: { $0.name == name }) {
    return match
  }
  return Flavour(
    name: name,
    accent: accentForCustomFlavour(name),
    sugarFree: name.range(of: #"sugar\s*free|zero"#, options: [.regularExpression, .caseInsensitive]) != nil
  )
}

func accentForCustomFlavour(_ name: String) -> String {
  let total = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
  return fallbackAccents[total % fallbackAccents.count]
}

func mergedFlavours(from entries: [RedBullEntry]) -> [Flavour] {
  let builtInNames = Set(builtInFlavours.map(\.name))
  let custom = entries.map(\.flavour)
    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !builtInNames.contains($0) }
    .stableUniqued()
    .sorted()
    .map(flavourMeta)
  return builtInFlavours + custom
}

struct AppTheme: Identifiable {
  var id: String
  var label: String
  var swatch: Color
  var primary: Color
  var secondary: Color
  var background: Color
  var surface: Color
  var text: Color
}

let appThemes: [AppTheme] = [
  AppTheme(
    id: "mist",
    label: "Mist",
    swatch: Color(hex: "#2563c7"),
    primary: Color(hex: "#2563c7"),
    secondary: Color(hex: "#00897b"),
    background: Color(hex: "#eef3fb"),
    surface: .white,
    text: Color(hex: "#202124")
  ),
  AppTheme(
    id: "aqua",
    label: "Aqua",
    swatch: Color(hex: "#007f73"),
    primary: Color(hex: "#007f73"),
    secondary: Color(hex: "#0b6f9f"),
    background: Color(hex: "#eef8f7"),
    surface: .white,
    text: Color(hex: "#172422")
  ),
  AppTheme(
    id: "signal-red",
    label: "Signal red",
    swatch: Color(hex: "#b3261e"),
    primary: Color(hex: "#b3261e"),
    secondary: Color(hex: "#7d5fff"),
    background: Color(hex: "#fbf1ef"),
    surface: .white,
    text: Color(hex: "#251312")
  ),
  AppTheme(
    id: "soft-pink",
    label: "Soft pink",
    swatch: Color(hex: "#a83f73"),
    primary: Color(hex: "#a83f73"),
    secondary: Color(hex: "#2563c7"),
    background: Color(hex: "#fbf1f6"),
    surface: .white,
    text: Color(hex: "#24151c")
  ),
]

let defaultThemeId = "mist"

func normaliseThemeId(_ id: String?) -> String {
  guard let id, !id.isEmpty else { return defaultThemeId }
  if appThemes.contains(where: { $0.id == id }) {
    return id
  }
  let legacy: [String: String] = [
    "oura-mist": "mist",
    "miku-blue": "aqua",
    "teto-red": "signal-red",
    "pastel-pink": "soft-pink",
    "original": "aqua",
    "zero": "mist",
    "summer": "soft-pink",
    "cherry": "signal-red",
    "spring": "soft-pink",
    "ruby": "signal-red",
    "sugarfree": "mist",
    "pink": "soft-pink",
    "blue": "aqua",
  ]
  return legacy[id] ?? defaultThemeId
}

func appTheme(_ id: String) -> AppTheme {
  appThemes.first(where: { $0.id == normaliseThemeId(id) }) ?? appThemes[0]
}

enum DateFilter: String, CaseIterable, Identifiable {
  case all
  case today
  case week
  case month
  case custom

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all: "All time"
    case .today: "Today"
    case .week: "This week"
    case .month: "This month"
    case .custom: "Custom range"
    }
  }
}

struct EntryFilters: Equatable {
  var flavour = "all"
  var dateRange: DateFilter = .all
  var store = ""
  var from: Date = Date()
  var to: Date = Date()
}

struct UserLimits: Equatable {
  var dailyCanLimit: Double?
  var dailySpendLimit: Double?
  var stopTime: String?

  var hasAnyLimit: Bool {
    dailyCanLimit != nil || dailySpendLimit != nil || stopTime != nil
  }
}

enum LimitViolation: String, Identifiable {
  case cans
  case spend
  case stopTime

  var id: String { rawValue }
}

struct LimitCheckResult: Equatable {
  var violations: [LimitViolation]
  var projectedCans: Double
  var projectedSpend: Double
  var todayCans: Double
  var todaySpend: Double
  var pastStopTime: Bool
}

struct Dashboard {
  var todayCans: String
  var weekCans: String
  var monthCans: String
  var allTimeCans: String
  var totalSpend: String
  var monthSpend: String
  var avgWeeklySpend: String
  var todayCaffeine: String
  var monthCaffeine: String
  var todaySugar: String
  var monthSugar: String
  var favouriteFlavour: String
  var priciestFlavour: String
  var priciestStore: String
  var currentStreak: String
  var daysWithoutRedBull: String
}

struct Insight: Identifiable {
  var id: String { label }
  var label: String
  var value: String
  var detail: String
}

struct DayPoint: Identifiable {
  var id: String { key }
  var key: String
  var label: String
  var spend: Double
  var cans: Double
  var caffeine: Double
  var sugar: Double
}

struct WeekPoint: Identifiable {
  var id: String { key }
  var key: String
  var label: String
  var spend: Double
  var cans: Double
}

struct FlavourPoint: Identifiable {
  var id: String { name }
  var name: String
  var value: Double
  var spend: Double
  var accent: String
}

enum Metrics {
  static let caffeinePer250Ml = 80.0
  static let sugarPer250Ml = 27.0

  static let standardCanValues: [Int: (pricePerCan: Double, caffeineMg: Double)] = [
    250: (1.75, 80),
    355: (2.20, 114),
    473: (2.85, 151),
  ]

  static let currency: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.numberStyle = .currency
    formatter.currencyCode = "GBP"
    return formatter
  }()

  static let oneDecimal: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0
    return formatter
  }()

  static let wholeNumber: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter
  }()

  static func money(_ value: Double) -> String {
    currency.string(from: NSNumber(value: value)) ?? String(format: "GBP %.2f", value)
  }

  static func one(_ value: Double) -> String {
    oneDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
  }

  static func whole(_ value: Double) -> String {
    wholeNumber.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
  }

  static func spend(for entry: RedBullEntry) -> Double {
    entry.cans * entry.pricePerCan
  }

  static func defaultPrice(for sizeMl: Int) -> Double {
    standardCanValues[sizeMl]?.pricePerCan ?? 0
  }

  static func caffeinePerCan(sizeMl: Int, override: Double? = nil) -> Double {
    if let override, override.isFinite, override >= 0 {
      return override
    }
    if let value = standardCanValues[sizeMl]?.caffeineMg {
      return value
    }
    return (Double(sizeMl) / 250.0) * caffeinePer250Ml
  }

  static func caffeine(for entry: RedBullEntry) -> Double {
    entry.cans * caffeinePerCan(sizeMl: entry.sizeMl, override: entry.caffeineMgPerCan)
  }

  static func sugar(for entry: RedBullEntry) -> Double {
    guard !entry.sugarFree else { return 0 }
    return entry.cans * (Double(entry.sizeMl) / 250.0) * sugarPer250Ml
  }

  static func buildEntry(userId: String, draft: EntryDraft, id: String = UUID().uuidString) -> RedBullEntry {
    let meta = flavourMeta(draft.flavour)
    var entry = RedBullEntry(
      id: id,
      userId: userId,
      cans: draft.cans,
      flavour: draft.flavour,
      flavourAccent: draft.flavourAccent.isEmpty ? meta.accent : draft.flavourAccent,
      sizeMl: draft.sizeMl,
      pricePerCan: draft.pricePerCan,
      dateTime: DateCodec.isoString(from: draft.date),
      notes: draft.notes,
      store: draft.store,
      sugarFree: draft.sugarFree || meta.sugarFree,
      caffeineMgPerCan: draft.caffeineMgPerCan,
      importKey: "",
      source: draft.source,
      createdAt: nil,
      updatedAt: nil
    )
    entry.importKey = makeImportKey(entry)
    return entry
  }

  static func makeImportKey(_ entry: RedBullEntry) -> String {
    [
      DateCodec.isoString(from: DateCodec.date(from: entry.dateTime) ?? Date()),
      entry.flavour.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      String(entry.sizeMl),
      String(format: "%.3f", entry.cans),
      String(format: "%.2f", entry.pricePerCan),
      entry.store.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
    ].joined(separator: "|")
  }

  static func isDuplicate(existing: [RedBullEntry], draft: EntryDraft) -> Bool {
    let entry = buildEntry(userId: "preview", draft: draft)
    let key = makeImportKey(entry)
    return existing.contains { $0.importKey == key || makeImportKey($0) == key }
  }

  static func sorted(_ entries: [RedBullEntry]) -> [RedBullEntry] {
    entries.sorted {
      (DateCodec.date(from: $0.dateTime) ?? .distantPast) > (DateCodec.date(from: $1.dateTime) ?? .distantPast)
    }
  }

  static func sum(_ entries: [RedBullEntry], _ selector: (RedBullEntry) -> Double) -> Double {
    entries.reduce(0) { $0 + selector($1) }
  }

  static func sum(_ entries: [RedBullEntry], _ keyPath: KeyPath<RedBullEntry, Double>) -> Double {
    entries.reduce(0) { $0 + $1[keyPath: keyPath] }
  }

  static func entriesInRange(_ entries: [RedBullEntry], start: Date, end: Date) -> [RedBullEntry] {
    entries.filter {
      guard let date = DateCodec.date(from: $0.dateTime) else { return false }
      return date >= start && date <= end
    }
  }

  static func applyFilters(_ entries: [RedBullEntry], filters: EntryFilters) -> [RedBullEntry] {
    let now = Date()
    var start: Date?
    var end: Date?

    switch filters.dateRange {
    case .all:
      break
    case .today:
      start = Calendar.current.startOfDay(for: now)
      end = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start!) ?? now
    case .week:
      start = startOfWeek(now)
      end = now
    case .month:
      start = startOfMonth(now)
      end = now
    case .custom:
      start = Calendar.current.startOfDay(for: filters.from)
      end = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Calendar.current.startOfDay(for: filters.to))
    }

    return entries.filter { entry in
      let date = DateCodec.date(from: entry.dateTime) ?? .distantPast
      let flavourMatches = filters.flavour == "all" || entry.flavour == filters.flavour
      let storeMatches = filters.store.isEmpty || entry.store.localizedCaseInsensitiveContains(filters.store)
      let startMatches = start.map { date >= $0 } ?? true
      let endMatches = end.map { date <= $0 } ?? true
      return flavourMatches && storeMatches && startMatches && endMatches
    }
  }

  // monday-start week math. if this looks wrong, blame calendar.firstWeekday, not me.
  static func startOfWeek(_ date: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let startOfDay = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: startOfDay)
    let diff = weekday == 1 ? -6 : 2 - weekday
    return calendar.date(byAdding: .day, value: diff, to: startOfDay) ?? startOfDay
  }

  static func startOfMonth(_ date: Date) -> Date {
    let components = Calendar.current.dateComponents([.year, .month], from: date)
    return Calendar.current.date(from: components) ?? Calendar.current.startOfDay(for: date)
  }

  static func daysBetween(_ left: Date, _ right: Date) -> Int {
    let l = Calendar.current.startOfDay(for: left)
    let r = Calendar.current.startOfDay(for: right)
    return Calendar.current.dateComponents([.day], from: l, to: r).day ?? 0
  }

  static func trackedWeeks(_ entries: [RedBullEntry]) -> Double {
    guard let first = entries.compactMap({ DateCodec.date(from: $0.dateTime) }).min() else {
      return 1
    }
    let days = max(1, ceil(Date().timeIntervalSince(first) / 86_400))
    return max(1, ceil(days / 7))
  }

  static func currentStreak(_ entries: [RedBullEntry]) -> Int {
    guard !entries.isEmpty else { return 0 }
    let days = Set(entries.compactMap { entry -> String? in
      guard let date = DateCodec.date(from: entry.dateTime) else { return nil }
      return formatDateKey(Calendar.current.startOfDay(for: date))
    })
    var cursor = Calendar.current.startOfDay(for: Date())
    var streak = 0
    while days.contains(formatDateKey(cursor)) {
      streak += 1
      cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
    }
    return streak
  }

  static func daysSinceLast(_ entries: [RedBullEntry]) -> Int {
    guard let latest = entries.compactMap({ DateCodec.date(from: $0.dateTime) }).max() else {
      return 0
    }
    return max(0, daysBetween(latest, Date()))
  }

  static func groupByDay(_ entries: [RedBullEntry]) -> [DayPoint] {
    var grouped: [String: DayPoint] = [:]
    entries.forEach { entry in
      guard let date = DateCodec.date(from: entry.dateTime) else { return }
      let key = formatDateKey(date)
      var point = grouped[key] ?? DayPoint(
        key: key,
        label: DateFormatters.shortDayMonth.string(from: date),
        spend: 0,
        cans: 0,
        caffeine: 0,
        sugar: 0
      )
      point.spend += spend(for: entry)
      point.cans += entry.cans
      point.caffeine += caffeine(for: entry)
      point.sugar += sugar(for: entry)
      grouped[key] = point
    }
    return grouped.values.sorted { $0.key < $1.key }.suffix(30).map { $0 }
  }

  static func groupByWeek(_ entries: [RedBullEntry]) -> [WeekPoint] {
    var grouped: [String: WeekPoint] = [:]
    entries.forEach { entry in
      guard let date = DateCodec.date(from: entry.dateTime) else { return }
      let week = startOfWeek(date)
      let key = formatDateKey(week)
      var point = grouped[key] ?? WeekPoint(
        key: key,
        label: "W/C \(DateFormatters.shortDayMonth.string(from: week))",
        spend: 0,
        cans: 0
      )
      point.spend += spend(for: entry)
      point.cans += entry.cans
      grouped[key] = point
    }
    return grouped.values.sorted { $0.key < $1.key }.suffix(10).map { $0 }
  }

  static func groupByFlavour(_ entries: [RedBullEntry]) -> [FlavourPoint] {
    var grouped: [String: FlavourPoint] = [:]
    entries.forEach { entry in
      var point = grouped[entry.flavour] ?? FlavourPoint(name: entry.flavour, value: 0, spend: 0, accent: entry.flavourAccent)
      point.value += entry.cans
      point.spend += spend(for: entry)
      grouped[entry.flavour] = point
    }
    return grouped.values.sorted { $0.value > $1.value }
  }

  static func topByCans(_ entries: [RedBullEntry]) -> String {
    groupByFlavour(entries).first?.name ?? "None yet"
  }

  static func highestAveragePrice(_ entries: [RedBullEntry], key: AveragePriceKey) -> (label: String, average: Double)? {
    var grouped: [String: (total: Double, cans: Double)] = [:]
    entries.forEach { entry in
      let label = key == .flavour ? entry.flavour : entry.store.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !label.isEmpty else { return }
      var current = grouped[label] ?? (0, 0)
      current.total += spend(for: entry)
      current.cans += entry.cans
      grouped[label] = current
    }
    return grouped.map { ($0.key, $0.value.cans > 0 ? $0.value.total / $0.value.cans : 0) }
      .sorted { $0.1 > $1.1 }
      .first
  }

  static func buildDashboard(entries: [RedBullEntry]) -> Dashboard {
    let now = Date()
    let todayStart = Calendar.current.startOfDay(for: now)
    let tomorrow = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: todayStart) ?? now
    let weekStart = startOfWeek(now)
    let monthStart = startOfMonth(now)
    let todayEntries = entriesInRange(entries, start: todayStart, end: tomorrow)
    let weekEntries = entriesInRange(entries, start: weekStart, end: now)
    let monthEntries = entriesInRange(entries, start: monthStart, end: now)
    let totalSpend = sum(entries, spend)
    let priceyFlavour = highestAveragePrice(entries, key: .flavour)
    let priceyStore = highestAveragePrice(entries, key: .store)

    return Dashboard(
      todayCans: one(sum(todayEntries, \.cans)),
      weekCans: "\(one(sum(weekEntries, \.cans))) cans",
      monthCans: one(sum(monthEntries, \.cans)),
      allTimeCans: one(sum(entries, \.cans)),
      totalSpend: money(totalSpend),
      monthSpend: money(sum(monthEntries, spend)),
      avgWeeklySpend: money(totalSpend / trackedWeeks(entries)),
      todayCaffeine: "\(whole(sum(todayEntries, caffeine)))mg",
      monthCaffeine: "\(whole(sum(monthEntries, caffeine)))mg",
      todaySugar: "\(one(sum(todayEntries, sugar)))g",
      monthSugar: "\(one(sum(monthEntries, sugar)))g",
      favouriteFlavour: topByCans(entries),
      priciestFlavour: priceyFlavour.map { "\($0.label) \(money($0.average))" } ?? "None yet",
      priciestStore: priceyStore.map { "\($0.label) \(money($0.average))" } ?? "No store yet",
      currentStreak: "\(currentStreak(entries))",
      daysWithoutRedBull: "\(daysSinceLast(entries))"
    )
  }

  static func buildInsights(entries: [RedBullEntry]) -> [Insight] {
    let now = Date()
    let weekStart = startOfWeek(now)
    let previousWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
    let previousWeekEnd = Calendar.current.date(byAdding: .second, value: -1, to: weekStart) ?? weekStart
    let monthStart = startOfMonth(now)
    let previousMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
    let previousMonthEnd = Calendar.current.date(byAdding: .second, value: -1, to: monthStart) ?? monthStart

    let thisMonthSpend = sum(entriesInRange(entries, start: monthStart, end: now), spend)
    let lastMonthSpend = sum(entriesInRange(entries, start: previousMonthStart, end: previousMonthEnd), spend)
    let thisWeekCans = sum(entriesInRange(entries, start: weekStart, end: now), \.cans)
    let lastWeekCans = sum(entriesInRange(entries, start: previousWeekStart, end: previousWeekEnd), \.cans)
    let sugarFreeCans = sum(entries.filter(\.sugarFree), \.cans)
    let allCans = sum(entries, \.cans)

    return [
      Insight(
        label: "Month spend",
        value: "You spent \(money(thisMonthSpend)) this month",
        detail: lastMonthSpend > 0 ? comparisonCopy(current: thisMonthSpend, previous: lastMonthSpend, suffix: "vs last month") : "No previous-month baseline yet."
      ),
      Insight(
        label: "Weekly pace",
        value: "\(one(thisWeekCans)) cans this week",
        detail: lastWeekCans > 0 ? comparisonCopy(current: thisWeekCans, previous: lastWeekCans, suffix: "vs last week") : "The weekly comparator wakes up after another week of data."
      ),
      Insight(
        label: "Zero sugar mix",
        value: allCans > 0 ? "\(one((sugarFreeCans / allCans) * 100))% sugar-free" : "No mix yet",
        detail: allCans > 0 ? "\(one(sugarFreeCans)) of \(one(allCans)) cans flagged sugar-free." : "Log a sugar-free entry to track the split."
      ),
    ]
  }

  static func comparisonCopy(current: Double, previous: Double, suffix: String) -> String {
    let difference = current - previous
    let percent = previous == 0 ? 0 : (difference / previous) * 100
    let direction = difference >= 0 ? "up" : "down"
    return "\(direction) \(one(abs(percent)))% \(suffix)"
  }

  static func formatMetricValue(name: String, value: Double) -> String {
    if name.localizedCaseInsensitiveContains("spend") {
      return money(value)
    }
    if name.localizedCaseInsensitiveContains("caffeine") {
      return "\(whole(value))mg"
    }
    if name.localizedCaseInsensitiveContains("sugar") {
      return "\(one(value))g"
    }
    return one(value)
  }

  static func formatDateKey(_ date: Date) -> String {
    DateFormatters.dateKey.string(from: date)
  }
}

enum AveragePriceKey {
  case flavour
  case store
}

enum Limits {
  static let canKey = "dailyCanLimit"
  static let spendKey = "dailySpendLimit"
  static let stopKey = "stopTime"

  static func parse(_ prefs: [String: Any]) -> UserLimits {
    var limits = UserLimits()
    if let can = doubleValue(prefs[canKey]), can > 0 {
      limits.dailyCanLimit = can
    }
    if let spend = doubleValue(prefs[spendKey]), spend >= 0 {
      limits.dailySpendLimit = spend
    }
    if let stop = prefs[stopKey] as? String, stop.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
      limits.stopTime = stop
    }
    return limits
  }

  static func serialize(_ limits: UserLimits) -> [String: Any] {
    var data: [String: Any] = [:]
    if let value = limits.dailyCanLimit, value > 0 {
      data[canKey] = value
    }
    if let value = limits.dailySpendLimit, value >= 0 {
      data[spendKey] = value
    }
    if let value = limits.stopTime, !value.isEmpty {
      data[stopKey] = value
    }
    return data
  }

  static func merge(existing: [String: Any], limits: UserLimits) -> [String: Any] {
    var next = existing
    next.removeValue(forKey: canKey)
    next.removeValue(forKey: spendKey)
    next.removeValue(forKey: stopKey)
    serialize(limits).forEach { next[$0.key] = $0.value }
    return next
  }

  static func evaluate(
    limits: UserLimits,
    entries: [RedBullEntry],
    draft: EntryDraft? = nil,
    excludeEntryId: String? = nil,
    at ref: Date = Date()
  ) -> LimitCheckResult {
    let todayEntries = entriesTodayBst(entries, ref: ref).filter { $0.id != excludeEntryId }
    let todayCans = Metrics.sum(todayEntries, \.cans)
    let todaySpend = Metrics.sum(todayEntries, Metrics.spend)
    let projectedCans = draft.map { todayCans + $0.cans } ?? todayCans
    let projectedSpend = draft.map { todaySpend + ($0.cans * $0.pricePerCan) } ?? todaySpend
    let checkTime = draft?.date ?? ref
    let pastStopTime = limits.stopTime.map { isPastStopTime($0, date: checkTime) } ?? false
    var violations: [LimitViolation] = []

    if let canLimit = limits.dailyCanLimit {
      let over = draft == nil ? todayCans >= canLimit : projectedCans > canLimit
      if over { violations.append(.cans) }
    }

    if let spendLimit = limits.dailySpendLimit {
      let over = draft == nil ? todaySpend >= spendLimit : projectedSpend > spendLimit
      if over { violations.append(.spend) }
    }

    if limits.stopTime != nil, pastStopTime {
      violations.append(.stopTime)
    }

    return LimitCheckResult(
      violations: violations,
      projectedCans: projectedCans,
      projectedSpend: projectedSpend,
      todayCans: todayCans,
      todaySpend: todaySpend,
      pastStopTime: pastStopTime
    )
  }

  // daily limits use london time because of course they do. timezones are a pain.
  static func entriesTodayBst(_ entries: [RedBullEntry], ref: Date = Date()) -> [RedBullEntry] {
    let key = bstDateKey(ref)
    return entries.filter { entry in
      guard let date = DateCodec.date(from: entry.dateTime) else { return false }
      return bstDateKey(date) == key
    }
  }

  static func bstDateKey(_ date: Date) -> String {
    DateFormatters.bstDateKey.string(from: date)
  }

  static func bstMinutes(_ date: Date = Date()) -> Int {
    let parts = DateFormatters.bstTime.string(from: date).split(separator: ":").compactMap { Int(String($0)) }
    guard parts.count == 2 else { return 0 }
    return parts[0] * 60 + parts[1]
  }

  static func stopTimeMinutes(_ stopTime: String) -> Int {
    let parts = stopTime.split(separator: ":").compactMap { Int(String($0)) }
    guard parts.count == 2 else { return 0 }
    return parts[0] * 60 + parts[1]
  }

  static func isPastStopTime(_ stopTime: String, date: Date = Date()) -> Bool {
    bstMinutes(date) >= stopTimeMinutes(stopTime)
  }

  static func stopTimeLabel(_ stopTime: String) -> String {
    let parts = stopTime.split(separator: ":").compactMap { Int(String($0)) }
    guard parts.count == 2 else { return stopTime }
    var components = DateComponents()
    components.hour = parts[0]
    components.minute = parts[1]
    let date = Calendar.current.date(from: components) ?? Date()
    return DateFormatters.clock.string(from: date)
  }

  static func progress(current: Double, limit: Double?) -> Double {
    guard let limit, limit > 0 else { return 0 }
    return min(1, current / limit)
  }

  static func statusMessage(violations: [LimitViolation], check: LimitCheckResult, limits: UserLimits) -> String {
    var lines: [String] = []
    if violations.contains(.cans), let limit = limits.dailyCanLimit {
      lines.append("This would bring you to \(String(format: "%.1f", check.projectedCans))/\(Metrics.one(limit)) cans today (BST).")
    }
    if violations.contains(.spend), let limit = limits.dailySpendLimit {
      lines.append("This would bring today's spend to \(Metrics.money(check.projectedSpend)) of your \(Metrics.money(limit)) limit.")
    }
    if violations.contains(.stopTime), let stop = limits.stopTime {
      lines.append("You're past your stop time (\(stopTimeLabel(stop)) BST).")
    }
    return lines.joined(separator: " ")
  }
}

struct BarcodeProductDraft: Codable, Equatable {
  var flavourName: String
  var sizeMl: Int
  var pricePerCan: Double
  var sugarFree: Bool?
  var caffeineMgPerCan: Double?
}

struct BarcodeSeedProduct: Codable, Equatable {
  var flavourName: String
  var sizeMl: Int
  var pricePerCan: Double
  var sugarFree: Bool?
  var caffeineMgPerCan: Double?
  var verifiedBy: String
  var sourceName: String?
  var sourceUrl: String?
  var notes: String?
  var variant: String?
}

struct UserBarcodeMapping: Codable, Equatable {
  var barcode: String
  var flavourName: String
  var sizeMl: Int
  var pricePerCan: Double
  var sugarFree: Bool?
  var caffeineMgPerCan: Double?
  var createdAt: String
  var updatedAt: String
}

struct ResolvedBarcodeProduct: Equatable {
  enum Source {
    case builtIn
    case user
  }

  var flavourName: String
  var sizeMl: Int
  var pricePerCan: Double
  var sugarFree: Bool
  var caffeineMgPerCan: Double?
  var flavourAccent: String
  var source: Source
}

struct BarcodeLookupCatalog {
  var verifiedProducts: [String: BarcodeSeedProduct] = [:]
  var userMappings: [UserBarcodeMapping] = []
}

enum BarcodeLookupResult: Equatable {
  case known(String, ResolvedBarcodeProduct)
  case user(String, ResolvedBarcodeProduct)
  case partial(String, BarcodeProductDraft, reason: String)
  case unknown(String)
}

enum BarcodeLookup {
  static func normalize(_ value: String) -> String {
    value.filter(\.isNumber)
  }

  static func lookup(_ rawBarcode: String, catalog: BarcodeLookupCatalog) -> BarcodeLookupResult {
    let barcode = normalize(rawBarcode)
    guard !barcode.isEmpty else {
      return .unknown(rawBarcode.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    if let mapping = catalog.userMappings.first(where: { $0.barcode == barcode }) {
      return .user(barcode, resolve(mapping, source: .user))
    }

    guard let seed = catalog.verifiedProducts[barcode] else {
      return .unknown(barcode)
    }

    let knownNames = Set(builtInFlavours.map(\.name))
    let product = BarcodeProductDraft(
      flavourName: seed.flavourName,
      sizeMl: seed.sizeMl,
      pricePerCan: seed.pricePerCan,
      sugarFree: seed.sugarFree,
      caffeineMgPerCan: seed.caffeineMgPerCan
    )
    guard knownNames.contains(seed.flavourName) else {
      return .partial(
        barcode,
        product,
        reason: "This barcode has product data, but its flavour is not in the built-in Red Bull list yet."
      )
    }
    return .known(barcode, resolve(product, source: .builtIn))
  }

  static func resolve(_ product: BarcodeProductDraft, source: ResolvedBarcodeProduct.Source) -> ResolvedBarcodeProduct {
    let meta = flavourMeta(product.flavourName)
    return ResolvedBarcodeProduct(
      flavourName: product.flavourName,
      sizeMl: product.sizeMl,
      pricePerCan: product.pricePerCan,
      sugarFree: product.sugarFree ?? meta.sugarFree,
      caffeineMgPerCan: product.caffeineMgPerCan,
      flavourAccent: meta.accent,
      source: source
    )
  }

  static func resolve(_ mapping: UserBarcodeMapping, source: ResolvedBarcodeProduct.Source) -> ResolvedBarcodeProduct {
    resolve(
      BarcodeProductDraft(
        flavourName: mapping.flavourName,
        sizeMl: mapping.sizeMl,
        pricePerCan: mapping.pricePerCan,
        sugarFree: mapping.sugarFree,
        caffeineMgPerCan: mapping.caffeineMgPerCan
      ),
      source: source
    )
  }

  static func entryDraft(product: ResolvedBarcodeProduct, barcode: String) -> EntryDraft {
    var draft = EntryDraft()
    draft.cans = 1
    draft.flavour = product.flavourName
    draft.flavourAccent = product.flavourAccent
    draft.sizeMl = product.sizeMl
    draft.pricePerCan = product.pricePerCan
    draft.date = Date()
    draft.notes = "Barcode scan: \(barcode)"
    draft.store = ""
    draft.sugarFree = product.sugarFree
    draft.caffeineMgPerCan = product.caffeineMgPerCan
    draft.source = .manual
    return draft
  }

  static func productCaffeineMg(_ product: BarcodeProductDraft) -> Double {
    Metrics.caffeinePerCan(sizeMl: product.sizeMl, override: product.caffeineMgPerCan)
  }
}

struct RedBullExportPayload: Codable {
  var app = "Red Bull Intake Tracker"
  var version = 1
  var exportedAt = DateCodec.isoString(from: Date())
  var entries: [RedBullEntry]
}

struct JSONExportDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }

  var data: Data

  init(data: Data = Data()) {
    self.data = data
  }

  init(entries: [RedBullEntry]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    data = try encoder.encode(RedBullExportPayload(entries: entries))
  }

  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

enum ImportParser {
  // accepts our export wrapper or a bare array — json import is forgiving on purpose.
  static func parseJSON(_ data: Data) throws -> [EntryDraft] {
    let decoder = JSONDecoder()
    if let payload = try? decoder.decode(RedBullExportPayload.self, from: data) {
      return payload.entries.map(coerce)
    }
    if let entries = try? decoder.decode([RedBullEntry].self, from: data) {
      return entries.map(coerce)
    }
    throw NSError(
      domain: "ImportParser",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Import file does not contain an entries array."]
    )
  }

  private static func coerce(_ entry: RedBullEntry) -> EntryDraft {
    var draft = EntryDraft()
    let meta = flavourMeta(entry.flavour)
    draft.cans = entry.cans
    draft.flavour = entry.flavour
    draft.flavourAccent = entry.flavourAccent.isEmpty ? meta.accent : entry.flavourAccent
    draft.sizeMl = entry.sizeMl
    draft.pricePerCan = entry.pricePerCan
    draft.date = DateCodec.date(from: entry.dateTime) ?? Date()
    draft.notes = entry.notes
    draft.store = entry.store
    draft.sugarFree = entry.sugarFree || meta.sugarFree
    draft.caffeineMgPerCan = entry.caffeineMgPerCan
    draft.source = .json
    return draft
  }
}

enum DateCodec {
  static let isoWithFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  static let isoWithoutFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  // appwrite dates might have fractional seconds or not. try both and hope.
  static func date(from value: String) -> Date? {
    isoWithFractional.date(from: value) ?? isoWithoutFractional.date(from: value)
  }

  static func isoString(from date: Date) -> String {
    isoWithFractional.string(from: date)
  }
}

enum DateFormatters {
  static let dateKey: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  static let bstDateKey: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_CA")
    formatter.timeZone = TimeZone(identifier: "Europe/London")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  static let bstTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.timeZone = TimeZone(identifier: "Europe/London")
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  static let shortDayMonth: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "dd MMM"
    return formatter
  }()

  static let humanDateTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  static let clock: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "h:mm a"
    return formatter
  }()
}

func doubleValue(_ value: Any?) -> Double? {
  switch value {
  case let double as Double:
    double
  case let float as Float:
    Double(float)
  case let int as Int:
    Double(int)
  case let string as String:
    Double(string)
  default:
    nil
  }
}

extension Sequence where Element: Hashable {
  func stableUniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

extension Color {
  init(hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)
    let red: UInt64
    let green: UInt64
    let blue: UInt64
    switch cleaned.count {
    case 3:
      red = (int >> 8) * 17
      green = (int >> 4 & 0xF) * 17
      blue = (int & 0xF) * 17
    default:
      red = int >> 16
      green = int >> 8 & 0xFF
      blue = int & 0xFF
    }
    self.init(
      .sRGB,
      red: Double(red) / 255,
      green: Double(green) / 255,
      blue: Double(blue) / 255,
      opacity: 1
    )
  }
}
