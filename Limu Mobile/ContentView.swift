import SwiftUI

struct ContentView: View {
    @StateObject private var appState: AppState
    @State private var selectedTab: AppTab
    @State private var showingNotifications: Bool
    @State private var shouldOpenKYC = false
    /// Cargo sits inside the Shipments tab; this says which of the two is showing.
    @State private var shipmentsSegment: String
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let args = ProcessInfo.processInfo.arguments
        _appState = StateObject(wrappedValue: AppState())
        var initialTab = AppTab.home
        if let index = args.firstIndex(of: "--tab"), args.indices.contains(index + 1),
           let tab = Self.tab(from: args[index + 1]) {
            initialTab = tab
        }
        _selectedTab = State(initialValue: initialTab == .cargo ? .shipments : initialTab)
        _shipmentsSegment = State(initialValue: initialTab == .cargo ? "Cargo" : "Shipments")
        _showingNotifications = State(initialValue: args.contains("--notifications"))
    }

    var body: some View {
        Group {
            if appState.isCheckingSession {
                ProgressView("Connecting to Limu…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(LimuColors.ink)
            } else if appState.isAuthenticated {
                mainApp
            } else {
                AuthenticationView {
                    selectedTab = .home
                }
            }
        }
        .environmentObject(appState)
        .environment(\.font, .limu(size: 14))
        .background(LimuColors.cream.ignoresSafeArea())
        .tint(LimuColors.copper)
        .preferredColorScheme(.light)
        .task { await appState.bootstrap() }
        .onReceive(NotificationCenter.default.publisher(for: .limuDidRegisterForRemoteNotifications)) { notification in
            guard let token = notification.userInfo?["token"] as? String else { return }
            Task { await appState.savePushToken(token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .limuRemoteNotificationReceived)) { _ in
            Task { await appState.refreshAfterRemoteNotification() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .limuRemoteNotificationTapped)) { notification in
            handleRemoteNotificationTap(notification)
        }
        .alert("Limu", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "Something went wrong.")
        }
    }

    private var mainApp: some View {
        VStack(spacing: 0) {
            LimuTopNav(unreadCount: appState.unreadCount) { showingNotifications = true }
            mainContent
        }
        .background(LimuColors.cream)
    }

    private var mainContent: some View {
        Group {
            if appState.isReactivating {
                // A reactivating account can do nothing until its fresh KYC is submitted: no tabs, no notifications.
                KYCView(
                    onBack: {
                        Task {
                            await appState.logout()
                            await MainActor.run { selectedTab = .home }
                        }
                    },
                    isReactivation: true
                )
            } else if showingNotifications {
                NotificationsView(
                    notifications: $appState.notifications,
                    onBack: { showingNotifications = false },
                    onNavigate: navigate
                )
            } else {
                TabView(selection: guardedTabSelection) {
                    Tab("Home", systemImage: AppTab.home.icon, value: AppTab.home) {
                        HomeView(
                            notifications: appState.notifications,
                            onNavigate: navigate,
                            onNotifications: { showingNotifications = true },
                            onOpenKYC: openKYC
                        )
                    }
                    Tab("Shipments", systemImage: AppTab.shipments.icon, value: AppTab.shipments) {
                        ShipmentsHubView(segment: $shipmentsSegment)
                    }
                    Tab("Order Forms", systemImage: AppTab.orderForms.icon, value: AppTab.orderForms) {
                        kycGated(feature: "Order Forms") { OrderFormsView() }
                    }
                    Tab("Invoices", systemImage: AppTab.invoices.icon, value: AppTab.invoices) {
                        InvoicesView()
                    }
                    Tab("Profile", systemImage: AppTab.profile.icon, value: AppTab.profile) {
                        ProfileView(shouldOpenKYC: $shouldOpenKYC) {
                            Task {
                                await appState.logout()
                                await MainActor.run { selectedTab = .home }
                            }
                        }
                    }
                    .badge(appState.unreadCount)
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .tint(LimuColors.sunsetOrange)
            }
        }
        .background(LimuColors.cream.ignoresSafeArea())
        .task(id: appState.isReactivating) {
            if appState.isReactivating { openKYC() }
        }
        // Visiting a tab, switching Shipments/Cargo, or coming back to the app reloads what is on screen.
        .onChange(of: selectedTab) { _, tab in
            Task { await appState.refresh(tab: tab) }
        }
        .onChange(of: shipmentsSegment) { _, _ in
            Task { await appState.refresh(tab: .shipments) }
        }
        .onChange(of: showingNotifications) { _, showing in
            if showing { Task { await appState.refreshNotifications() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, appState.isAuthenticated {
                Task { await appState.refresh(tab: selectedTab) }
            }
        }
    }

    @ViewBuilder
    private func kycGated<Content: View>(feature: String, @ViewBuilder content: () -> Content) -> some View {
        if appState.hasCompletedKYC {
            content()
        } else {
            KYCRestrictedView(feature: feature, onCompleteKYC: openKYC)
        }
    }

    private var guardedTabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { navigate($0) }
        )
    }

    private func navigate(_ tab: AppTab) {
        showingNotifications = false
        if tab == .cargo {
            shipmentsSegment = "Cargo"
            selectedTab = .shipments
        } else {
            selectedTab = tab
        }
    }

    private func openKYC() {
        showingNotifications = false
        shouldOpenKYC = true
        selectedTab = .profile
    }

    private func handleRemoteNotificationTap(_ notification: Notification) {
        Task { await appState.refreshAfterRemoteNotification() }
        guard appState.isAuthenticated else { return }
        if let link = Self.notificationLink(from: notification) {
            appState.pendingLink = link
            navigate(link.tab)
        } else if let destination = Self.notificationDestination(from: notification) {
            navigate(destination)
        } else {
            showingNotifications = true
        }
    }

    /// The push payload carries `objectType` and `objectId`; together they name the exact record to open.
    private static func notificationLink(from notification: Notification) -> DeepLink? {
        guard let userInfo = notification.userInfo,
              let objectType = userInfo["objectType"] as? String else { return nil }
        let objectID: Int?
        if let number = userInfo["objectId"] as? Int {
            objectID = number
        } else if let text = userInfo["objectId"] as? String {
            objectID = Int(text)
        } else if let number = userInfo["objectId"] as? NSNumber {
            objectID = number.intValue
        } else {
            objectID = nil
        }
        return DeepLink(objectType: objectType, objectID: objectID)
    }

    private static func notificationDestination(from notification: Notification) -> AppTab? {
        guard let userInfo = notification.userInfo else { return nil }
        let rawDestination = (userInfo["destination"] as? String)
            ?? (userInfo["tab"] as? String)
            ?? (userInfo["objectType"] as? String)
        guard let rawDestination else { return nil }
        switch rawDestination.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "cargo":
            return .cargo
        case "shipment", "shipments":
            return .shipments
        case "order", "order form", "order forms", "orderform", "orderforms":
            return .orderForms
        case "invoice", "invoices", "payment", "payments":
            return .invoices
        case "profile", "kyc":
            return .profile
        case "home", "notifications":
            return .home
        default:
            return nil
        }
    }

    private static func tab(from rawValue: String) -> AppTab? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        switch normalized {
        case "home": return .home
        case "cargo": return .cargo
        case "shipment", "shipments": return .shipments
        case "order", "order form", "order forms", "orderform", "orderforms": return .orderForms
        case "invoice", "invoices": return .invoices
        case "profile": return .profile
        default: return nil
        }
    }

}

private struct KYCRestrictedView: View {
    let feature: String
    let onCompleteKYC: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PageHeader {
                Text(feature)
                    .font(.limu(size: 18, weight: .bold))
            }
            VStack(spacing: 16) {
                BrandEmptyStateIcon(systemName: "lock.shield", symbolSize: 40)
                Text("Complete KYC to access \(feature)")
                    .font(.limu(size: 18, weight: .bold))
                    .foregroundStyle(LimuColors.ink)
                    .multilineTextAlignment(.center)
                Text("Add your KYC details once to unlock your logistics information immediately.")
                    .font(.limu(size: 13))
                    .foregroundStyle(LimuColors.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                PrimaryButton(title: "Complete KYC", action: onCompleteKYC)
                    .frame(maxWidth: 240)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(LimuColors.cream.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
