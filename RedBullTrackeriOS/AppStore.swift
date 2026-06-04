import Foundation
import SwiftUI

enum AuthMode {
  case login
  case signup
}

struct QuickAdd: Identifiable {
  var id: String { label }
  var label: String
  var flavour: String
  var sizeMl: Int
  var pricePerCan: Double
}

let quickAdds: [QuickAdd] = [
  QuickAdd(label: "Original", flavour: "Original", sizeMl: 250, pricePerCan: 1.75),
  QuickAdd(label: "Sugar Free", flavour: "Sugar Free", sizeMl: 250, pricePerCan: 1.75),
  QuickAdd(label: "Iced Vanilla", flavour: "Iced Vanilla", sizeMl: 250, pricePerCan: 1.75),
  QuickAdd(label: "473ml Original", flavour: "Original", sizeMl: 473, pricePerCan: 2.85),
]

@MainActor
final class AppStore: ObservableObject {
  @Published var user: AppwriteUser?
  @Published var entries: [RedBullEntry] = []
  @Published var filters = EntryFilters()
  @Published var activeView: AppView = .overview
  @Published var themeId: String = UserDefaults.standard.string(forKey: "red-bull-intake-tracker.theme.v2") ?? defaultThemeId
  @Published var userLimits = UserLimits()
  @Published var authLoading = true
  @Published var dataLoading = false
  @Published var busyAction: String?
  @Published var notice = "Appwrite session pending."
  @Published var setupStatus: SetupStatus = .checking("Pinging Appwrite...")
  @Published var syncError = ""
  @Published var authError = ""
  @Published var setupOpen = false
  @Published var pendingLimitDraft: EntryDraft?
  @Published var pendingLimitEditingId: String?
  @Published var limitOverrideMessage = ""
  @Published var showLimitOverride = false

  let appwrite: AppwriteService
  let intakeRepository: IntakeRepository
  let barcodeRepository: BarcodeRepository

  init(appwrite: AppwriteService = AppwriteService()) {
    self.appwrite = appwrite
    intakeRepository = IntakeRepository(service: appwrite)
    barcodeRepository = BarcodeRepository(service: appwrite)
    themeId = normaliseThemeId(themeId)
  }

  var activeTheme: AppTheme {
    appTheme(themeId)
  }

  var allFlavours: [Flavour] {
    mergedFlavours(from: entries)
  }

  var entriesInView: [RedBullEntry] {
    Metrics.sorted(Metrics.applyFilters(entries, filters: filters))
  }

  var dashboard: Dashboard {
    Metrics.buildDashboard(entries: entries)
  }

  var insights: [Insight] {
    Metrics.buildInsights(entries: entries)
  }

  var limitCheck: LimitCheckResult {
    Limits.evaluate(limits: userLimits, entries: entries)
  }

  var chartData: [DayPoint] {
    Metrics.groupByDay(entriesInView)
  }

  var weekData: [WeekPoint] {
    Metrics.groupByWeek(entriesInView)
  }

  var flavourData: [FlavourPoint] {
    Metrics.groupByFlavour(entriesInView)
  }

  var recentEntries: [RedBullEntry] {
    Array(entries.prefix(5))
  }

  func bootstrap() async {
    authLoading = true
    authError = ""
    do {
      _ = try await appwrite.ping()
      setupStatus = .ok("Appwrite ping succeeded.")
    } catch {
      setupStatus = .error(error.localizedDescription)
    }

    do {
      let currentUser = try await appwrite.currentUser()
      applyUser(currentUser)
      notice = "Signed in as \(currentUser.email.isEmpty ? currentUser.name : currentUser.email)."
      if !isOnboarded(currentUser) {
        setupOpen = true
      }
      await refreshEntries(showLoader: true)
    } catch {
      user = nil
      entries = []
      notice = "Sign in to sync entries across devices."
    }
    authLoading = false
  }

  func login(email: String, password: String) async {
    busyAction = "auth"
    authError = ""
    do {
      let currentUser = try await appwrite.login(email: email, password: password)
      applyUser(currentUser)
      notice = "Signed in as \(currentUser.email)."
      if !isOnboarded(currentUser) {
        setupOpen = true
      }
      await refreshEntries(showLoader: true)
    } catch {
      authError = appwriteErrorMessage(error)
    }
    busyAction = nil
  }

  func signup(name: String, email: String, password: String) async {
    busyAction = "auth"
    authError = ""
    do {
      let currentUser = try await appwrite.signup(name: name, email: email, password: password)
      applyUser(currentUser)
      notice = "Welcome, \(currentUser.name.isEmpty ? currentUser.email : currentUser.name)."
      setupOpen = true
      await refreshEntries(showLoader: true)
    } catch {
      authError = appwriteErrorMessage(error)
    }
    busyAction = nil
  }

  func logout() async {
    busyAction = "logout"
    syncError = ""
    do {
      try await appwrite.logout()
      user = nil
      entries = []
      notice = "Logged out."
    } catch {
      syncError = appwriteErrorMessage(error)
    }
    busyAction = nil
  }

  // sync model: open app, pull to refresh, save something. no live websocket fairy dust.
  func refreshEntries(showLoader: Bool = true) async {
    guard let user else { return }
    if showLoader {
      dataLoading = true
    }
    syncError = ""
    do {
      let remoteEntries = try await intakeRepository.listEntries(userId: user.id)
      entries = Metrics.sorted(remoteEntries)
      notice = "Synced \(remoteEntries.count) Appwrite \(remoteEntries.count == 1 ? "entry" : "entries")."
    } catch {
      syncError = appwriteErrorMessage(error)
      notice = "Appwrite sync failed."
    }
    if showLoader {
      dataLoading = false
    }
  }

  func saveUserLimits(_ next: UserLimits) async {
    guard let user else { return }
    busyAction = "save-limits"
    syncError = ""
    do {
      let prefs = Limits.merge(existing: AppwriteService.prefsDictionary(from: user), limits: next)
      let currentUser = try await appwrite.updatePrefs(prefs)
      applyUser(currentUser)
      notice = "Daily limits saved to your account."
    } catch {
      syncError = appwriteErrorMessage(error)
    }
    busyAction = nil
  }

  func saveOnboarding(limits: UserLimits, onboardingThemeId: String) async {
    guard let user else { return }
    busyAction = "save-onboarding"
    syncError = ""
    do {
      var prefs = Limits.merge(existing: AppwriteService.prefsDictionary(from: user), limits: limits)
      prefs["themeId"] = onboardingThemeId
      prefs["onboarded"] = true
      let currentUser = try await appwrite.updatePrefs(prefs)
      applyUser(currentUser)
      setThemeId(onboardingThemeId, sync: false)
      setupOpen = false
      notice = "Setup saved."
    } catch {
      syncError = appwriteErrorMessage(error)
    }
    busyAction = nil
  }

  func setThemeId(_ nextThemeId: String, sync: Bool = true) {
    let normalised = normaliseThemeId(nextThemeId)
    themeId = normalised
    UserDefaults.standard.set(normalised, forKey: "red-bull-intake-tracker.theme.v2")
    guard sync else { return }
    Task { await saveThemePreference(normalised) }
  }

  func saveThemePreference(_ nextThemeId: String) async {
    guard let user else { return }
    do {
      var prefs = AppwriteService.prefsDictionary(from: user)
      prefs["themeId"] = nextThemeId
      let currentUser = try await appwrite.updatePrefs(prefs)
      applyUser(currentUser)
    } catch {
      syncError = appwriteErrorMessage(error)
    }
  }

  // stop you before you blow past daily limits unless you insist like a gremlin.
  func stageDraftForSave(_ draft: EntryDraft, editingId: String? = nil) {
    let check = Limits.evaluate(limits: userLimits, entries: entries, draft: draft, excludeEntryId: editingId)
    if check.violations.isEmpty {
      Task { await saveDraft(draft, editingId: editingId) }
      return
    }
    pendingLimitDraft = draft
    pendingLimitEditingId = editingId
    limitOverrideMessage = Limits.statusMessage(violations: check.violations, check: check, limits: userLimits)
    showLimitOverride = true
  }

  func confirmLimitOverride() async {
    guard let draft = pendingLimitDraft else { return }
    let editingId = pendingLimitEditingId
    clearLimitOverride()
    await saveDraft(draft, editingId: editingId)
  }

  func clearLimitOverride() {
    pendingLimitDraft = nil
    pendingLimitEditingId = nil
    limitOverrideMessage = ""
    showLimitOverride = false
  }

  func saveDraft(_ draft: EntryDraft, editingId: String? = nil) async {
    guard let user else { return }
    busyAction = editingId == nil ? "save-entry" : "update-entry"
    syncError = ""
    do {
      let saved: RedBullEntry
      if let editingId {
        saved = try await intakeRepository.updateEntry(userId: user.id, id: editingId, draft: draft)
        entries = Metrics.sorted(entries.map { $0.id == saved.id ? saved : $0 })
        notice = "Entry updated in Appwrite."
      } else {
        saved = try await intakeRepository.createEntry(userId: user.id, draft: draft)
        entries = Metrics.sorted([saved] + entries)
        notice = "Entry saved to Appwrite."
      }
    } catch {
      syncError = appwriteErrorMessage(error)
    }
    busyAction = nil
  }

  func quickAdd(_ item: QuickAdd) {
    var draft = EntryDraft()
    let meta = flavourMeta(item.flavour)
    draft.cans = 1
    draft.flavour = item.flavour
    draft.flavourAccent = meta.accent
    draft.sizeMl = item.sizeMl
    draft.pricePerCan = item.pricePerCan
    draft.date = Date()
    draft.sugarFree = meta.sugarFree
    draft.notes = "Quick add"
    draft.store = ""
    draft.source = .quickAdd
    stageDraftForSave(draft)
  }

  func deleteEntry(_ entry: RedBullEntry) async {
    busyAction = "delete-\(entry.id)"
    syncError = ""
    do {
      try await intakeRepository.deleteEntry(id: entry.id)
      entries.removeAll { $0.id == entry.id }
      notice = "Entry deleted from Appwrite."
    } catch {
      syncError = appwriteErrorMessage(error)
    }
    busyAction = nil
  }

  func resetAll() async {
    busyAction = "reset"
    syncError = ""
    do {
      for entry in entries {
        try await intakeRepository.deleteEntry(id: entry.id)
      }
      entries = []
      filters = EntryFilters()
      notice = "All Appwrite entries deleted."
    } catch {
      syncError = appwriteErrorMessage(error)
    }
    busyAction = nil
  }

  func importJSON(from url: URL) async {
    guard let user else { return }
    busyAction = "json-import"
    syncError = ""
    do {
      // ios sandbox tantrum — you need the scoped resource dance to read a picked file.
      let accessed = url.startAccessingSecurityScopedResource()
      defer {
        if accessed {
          url.stopAccessingSecurityScopedResource()
        }
      }
      let data = try Data(contentsOf: url)
      let drafts = try ImportParser.parseJSON(data)
      let uniqueDrafts = drafts.filter { !Metrics.isDuplicate(existing: entries, draft: $0) }
      guard !uniqueDrafts.isEmpty else {
        notice = "No new JSON entries found."
        busyAction = nil
        return
      }
      let saved = try await intakeRepository.createEntries(userId: user.id, drafts: uniqueDrafts)
      entries = Metrics.sorted(saved + entries)
      notice = "\(saved.count) JSON \(saved.count == 1 ? "entry" : "entries") saved to Appwrite."
    } catch {
      syncError = error.localizedDescription
    }
    busyAction = nil
  }

  func loadBarcodeCatalog() async -> BarcodeLookupCatalog {
    guard let user else { return BarcodeLookupCatalog() }
    return await barcodeRepository.listCatalog(userId: user.id)
  }

  func saveBarcodeMapping(barcode: String, product: BarcodeProductDraft) async -> UserBarcodeMapping? {
    guard let user else { return nil }
    return await barcodeRepository.upsertUserMapping(userId: user.id, barcodeValue: barcode, product: product)
  }

  private func applyUser(_ currentUser: AppwriteUser) {
    user = currentUser
    let prefs = AppwriteService.prefsDictionary(from: currentUser)
    userLimits = Limits.parse(prefs)
    if let theme = prefs["themeId"] as? String, !theme.isEmpty {
      setThemeId(theme, sync: false)
    }
  }

  private func isOnboarded(_ currentUser: AppwriteUser) -> Bool {
    let prefs = AppwriteService.prefsDictionary(from: currentUser)
    return boolValue(prefs["onboarded"]) ?? false
  }
}

enum SetupStatus: Equatable {
  case checking(String)
  case ok(String)
  case error(String)

  var message: String {
    switch self {
    case .checking(let message), .ok(let message), .error(let message):
      message
    }
  }

  var isOK: Bool {
    if case .ok = self {
      return true
    }
    return false
  }
}

// appwrite prefs come back as bool, number, or string depending on mood. figure it out yourself.
func boolValue(_ value: Any?) -> Bool? {
  switch value {
  case let bool as Bool:
    return bool
  case let number as NSNumber:
    return number.boolValue
  case let string as String:
    if ["true", "1", "yes"].contains(string.lowercased()) { return true }
    if ["false", "0", "no"].contains(string.lowercased()) { return false }
    return nil
  default:
    return nil
  }
}

func firstName(_ user: AppwriteUser?) -> String {
  guard let user else { return "there" }
  let fallback = user.email.split(separator: "@").first.map(String.init) ?? "there"
  let value = (user.name.isEmpty ? fallback : user.name).trimmingCharacters(in: .whitespacesAndNewlines)
  return value.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "there"
}

func userInitial(_ user: AppwriteUser?) -> String {
  let value = user?.name.isEmpty == false ? user?.name : user?.email
  return String(value?.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "R").uppercased()
}
