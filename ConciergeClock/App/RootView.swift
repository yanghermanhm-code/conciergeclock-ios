import ConciergeCore
import GGSBrand
import SwiftUI

/// Four tabs (Alarms, Concierge, Sounds, Trends); Settings opens from the gear in the top bar.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.l10n) private var l10n
    @State private var showingSettings = false
    @State private var openedBackup: BackupPayload?
    @State private var backupError: String?

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab(l10n["tab.alarms"], systemImage: "alarm", value: AppTab.alarms) {
                NavigationStack {
                    AlarmsView()
                        .brandedNavigationBar(showingSettings: $showingSettings)
                }
            }
            Tab(l10n["tab.concierge"], systemImage: "bell", value: AppTab.concierge) {
                NavigationStack {
                    ConciergeView()
                        .brandedNavigationBar(showingSettings: $showingSettings)
                }
            }
            Tab(l10n["tab.sounds"], systemImage: "waveform", value: AppTab.sounds) {
                NavigationStack {
                    SoundsView()
                        .brandedNavigationBar(showingSettings: $showingSettings)
                }
            }
            Tab(l10n["tab.trends"], systemImage: "chart.line.uptrend.xyaxis", value: AppTab.trends) {
                NavigationStack {
                    TrendsView()
                        .brandedNavigationBar(showingSettings: $showingSettings)
                }
            }
        }
        .tint(ConciergeStyle.tint)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert(l10n["error.title"], isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button(l10n["common.ok"], role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        // A .conciergeclock backup opened from Files, AirDrop or Mail.
        .onOpenURL { url in
            guard url.pathExtension.lowercased() == BackupPayload.fileExtension else { return }
            showingSettings = false
            Task {
                do {
                    openedBackup = try await model.backups.readBackup(at: url)
                } catch {
                    backupError = l10n.backupErrorMessage(error)
                }
            }
        }
        .restoreConfirmation($openedBackup, errorMessage: $backupError)
        .alert(l10n["backup.openFailed"], isPresented: Binding(get: { backupError != nil }, set: { if !$0 { backupError = nil } })) {
            Button(l10n["common.ok"], role: .cancel) {}
        } message: {
            Text(backupError ?? "")
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: model.didBecomeActive()
            case .background: model.didEnterBackground()
            default: break
            }
        }
        .onChange(of: model.settings.settings.appIcon) { _, icon in
            model.applyAppIcon(icon)
        }
        .onChange(of: model.settings.settings.wakeScoreRules) { _, _ in
            model.rescoreWakeLog()
        }
        // Snooze length, days off, calendars left out, language of the alarm buttons…
        .onChange(of: model.settings.settings) { _, _ in
            model.scheduler.setNeedsReconcile()
        }
        // An account added or a calendar changed: days off may have changed.
        .onChange(of: model.calendars.calendarAccounts) { _, _ in
            model.scheduler.setNeedsReconcile()
        }
    }
}

/// The top bar shown on every main screen:
///   [butler logo]     Concierge Clock     [⚙︎]
/// Tapping the logo opens "About Greater Good Software". In right-to-left languages the logo
/// and gear swap sides automatically.
private struct BrandedNavigationBar: ViewModifier {
    @Binding var showingSettings: Bool
    @Environment(\.l10n) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCompany = false

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCompany = true
                    } label: {
                        ButlerNetworkMark(style: colorScheme == .dark ? .onDark : .standard)
                            .frame(width: 34, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n["a11y.companyLogo"])
                    .accessibilityIdentifier("nav.logo")
                }
                ToolbarItem(placement: .principal) {
                    // Product name — never translated.
                    Text(verbatim: "Concierge Clock")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.focus)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(l10n["common.settings"])
                    .accessibilityIdentifier("nav.settings")
                }
            }
            .sheet(isPresented: $showingCompany) {
                AboutCompanyView()
            }
    }
}

extension View {
    func brandedNavigationBar(showingSettings: Binding<Bool>) -> some View {
        modifier(BrandedNavigationBar(showingSettings: showingSettings))
    }
}

/// Concierge Clock's own colours on top of the shared Greater Good theme (GGSBrand.Theme).
/// Teal for interactive elements (accessible contrast in light and dark), brass for
/// decoration. See docs/DECISIONS.md.
enum ConciergeStyle {
    /// Buttons, toggles, links: ≥ 4.5:1 against the background in both appearances.
    static let tint = Color(light: 0x0B7470, dark: 0x3FCFC6)
    /// Decorative brass (rings, badges, the clock).
    static let brass = Color(light: 0xA9822A, dark: 0xD9B65E)
    /// Brass → teal, like the app icon's ring.
    static let ringGradient = LinearGradient(
        colors: [Brand.brassOnDark, Brand.teal], startPoint: .topTrailing, endPoint: .bottomLeading
    )
}
