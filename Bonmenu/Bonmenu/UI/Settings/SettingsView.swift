import SwiftUI

/// Main Settings view with tabbed panes.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsPane()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsPane()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            AdvancedSettingsPane()
                .environmentObject(appState)
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 480, height: 360)
    }
}
