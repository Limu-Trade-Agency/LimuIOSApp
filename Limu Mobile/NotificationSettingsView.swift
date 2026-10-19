import SwiftUI

/// Which channels may reach the client and which kinds of update they want. The in-app list always shows
/// everything; these settings only control what is sent outside the app.
struct NotificationPreferencesDTO: Codable, Equatable {
    struct Channels: Codable, Equatable {
        var push = true
        var email = false
        var whatsapp = false
    }

    struct Types: Codable, Equatable {
        var shipments = true
        var orders = true
        var invoices = true
        var general = true
    }

    var channels = Channels()
    var types = Types()
}

struct NotificationSettingsView: View {
    @EnvironmentObject private var appState: AppState
    let onBack: () -> Void

    @State private var preferences = NotificationPreferencesDTO()
    @State private var loaded = false
    @State private var saveFailed = false

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Profile", title: "Notification Settings", subtitle: "Choose how and what we tell you", onBack: onBack)
            ScrollView {
                VStack(spacing: 14) {
                    SectionCard("How we reach you") {
                        toggleRow("Push notifications", detail: "Alerts on this phone", icon: "bell", isOn: $preferences.channels.push)
                        toggleRow("WhatsApp", detail: "Messages to your registered number", icon: "message", isOn: $preferences.channels.whatsapp)
                        toggleRow("Email", detail: "Updates to your account email", icon: "envelope", isOn: $preferences.channels.email, last: true)
                    }
                    SectionCard("What we tell you about") {
                        toggleRow("Shipment alerts", detail: "Cargo and shipment progress, collection", icon: "ferry", isOn: $preferences.types.shipments)
                        toggleRow("Order forms", detail: "Items to review and order progress", icon: "list.clipboard", isOn: $preferences.types.orders)
                        toggleRow("Invoices and payments", detail: "New invoices and payment decisions", icon: "doc.text", isOn: $preferences.types.invoices)
                        toggleRow("General updates", detail: "Account, KYC and support updates", icon: "info.circle", isOn: $preferences.types.general, last: true)
                    }
                    Text("The notifications list in the app always shows everything. These settings only control what is sent outside the app.")
                        .font(.limu(size: 11))
                        .foregroundStyle(LimuColors.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if saveFailed {
                        Label("Your changes could not be saved. Check your connection and try again.", systemImage: "exclamationmark.triangle.fill")
                            .font(.limu(size: 11, weight: .medium))
                            .foregroundStyle(LimuColors.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .background(LimuColors.cream)
        .task {
            if let loadedPreferences = await appState.loadNotificationPreferences() {
                preferences = loadedPreferences
            }
            loaded = true
        }
        .onChange(of: preferences) { _, value in
            guard loaded else { return }
            Task { saveFailed = !(await appState.saveNotificationPreferences(value)) }
        }
    }

    private func toggleRow(_ title: String, detail: String, icon: String, isOn: Binding<Bool>, last: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.limu(size: 16, weight: .medium))
                .foregroundStyle(LimuColors.copper)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.limu(size: 14, weight: .semibold)).foregroundStyle(LimuColors.ink)
                Text(detail).font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn).labelsHidden().tint(LimuColors.copper)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(LimuColors.softCream).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}
