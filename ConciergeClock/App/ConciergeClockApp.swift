import ConciergeCore
import GGSBrand
import SwiftUI

@main
struct ConciergeClockApp: App {
    @State private var launch: LaunchState

    init() {
        _launch = State(initialValue: LaunchState.make())
    }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case let .ready(model):
                AppRoot(model: model)
            case let .failed(message):
                LaunchErrorView(message: message)
                    .localized(Localizer(language: .systemDefault))
            }
        }
        // An offline AI model download that finished while Concierge Clock was closed.
        .backgroundTask(.urlSession(ModelService.sessionIdentifier)) {
            await ModelService.handleBackgroundEvents()
        }
    }
}

/// Applies the user's language and theme, and shows the launch animation on top of the app
/// on every cold launch. Reading the settings inside a view body means SwiftUI re-renders
/// everything as soon as they change in Settings.
private struct AppRoot: View {
    let model: AppModel
    @State private var showingLaunch = true

    var body: some View {
        let settings = model.settings.settings
        ZStack {
            RootView()
            if showingLaunch {
                LaunchView {
                    showingLaunch = false
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(model)
        .localized(Localizer(language: AppLanguage.resolve(code: settings.languageCode)))
        .preferredColorScheme(settings.theme.colorScheme)
        .task { model.start() }
    }
}

/// Opening the database is the only thing that can fail at launch.
enum LaunchState {
    case ready(AppModel)
    case failed(String)

    @MainActor
    static func make() -> LaunchState {
        do {
            return .ready(try AppModel.live())
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

extension ThemePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct LaunchErrorView: View {
    let message: String
    @Environment(\.l10n) private var l10n

    var body: some View {
        ContentUnavailableView {
            Label(l10n["error.launchTitle"], systemImage: "exclamationmark.triangle")
        } description: {
            Text(l10n("error.launchMessage", message))
        }
    }
}
