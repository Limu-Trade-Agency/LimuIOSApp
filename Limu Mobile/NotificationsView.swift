import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var notifications: [AppNotification]
    let onBack: () -> Void
    let onNavigate: (AppTab) -> Void
    /// Inbox holds what needs attention; Archive holds what the client filed away.
    @State private var section = "Inbox"

    private var showingArchive: Bool { section == "Archive" }
    private var unreadCount: Int { notifications.filter(\.isUnread).count }
    private var readCount: Int { notifications.filter { !$0.isUnread }.count }
    private var shown: [AppNotification] { showingArchive ? appState.archivedNotifications : notifications }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader {
                HStack(spacing: 10) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.limu(size: 14, weight: .bold))
                            .foregroundStyle(LimuColors.copper)
                    }
                    .buttonStyle(.plain)
                    Text("Notifications")
                        .font(.limu(size: 18, weight: .bold))
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.limu(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(LimuColors.copper)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if !showingArchive && unreadCount > 0 {
                        Button("Mark all read") {
                            Task { await appState.markAllRead() }
                        }
                        .font(.limu(size: 12, weight: .semibold))
                        .foregroundStyle(LimuColors.copper)
                        .buttonStyle(.plain)
                    }
                    if !showingArchive && readCount > 0 {
                        Button("Archive read") {
                            Task {
                                for notification in notifications where !notification.isUnread {
                                    await appState.changeNotification(notification, action: "archive")
                                }
                            }
                        }
                        .font(.limu(size: 12, weight: .semibold))
                        .foregroundStyle(LimuColors.copper)
                        .buttonStyle(.plain)
                    }
                }
            }

            SegmentedTabs(items: ["Inbox", "Archive"], selection: $section)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            if shown.isEmpty {
                VStack(spacing: 12) {
                    GradientIconTile(systemName: showingArchive ? "archivebox" : "bell.slash", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 108, symbolSize: 42)
                    Text(showingArchive ? "Nothing archived" : "No Notifications").font(.limu(size: 15, weight: .bold))
                    Text(showingArchive ? "Archived notifications appear here." : "You're all caught up!")
                        .font(.limu(size: 13)).foregroundStyle(LimuColors.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Swipe actions need a List: swipe right to archive (or restore), swipe left to delete.
                List {
                    ForEach(shown) { notification in
                        Button { open(notification) } label: { notificationCard(notification) }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if showingArchive {
                                    Button { act(notification, "restore") } label: { Label("Restore", systemImage: "tray.and.arrow.up") }
                                        .tint(LimuColors.copper)
                                } else {
                                    Button { act(notification, "archive") } label: { Label("Archive", systemImage: "archivebox") }
                                        .tint(LimuColors.copper)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { act(notification, "delete") } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await reload() }
            }
        }
        .background(LimuColors.cream.ignoresSafeArea())
        .task { await reload() }
    }

    private func reload() async {
        await appState.refreshNotifications()
        await appState.refreshArchivedNotifications()
    }

    private func act(_ notification: AppNotification, _ action: String) {
        Task { await appState.changeNotification(notification, action: action) }
    }

    /// Opens the exact record the notification is about (the specific shipment update or cargo, the specific
    /// invoice or order form), falling back to the owning tab only when it names no record.
    private func open(_ notification: AppNotification) {
        Task { await appState.markRead(notification) }
        let link = appState.deepLink(for: notification)
        appState.pendingLink = link
        onNavigate(link?.tab ?? notification.destination)
    }

    private func notificationCard(_ notification: AppNotification) -> some View {
        ZStack(alignment: .leading) {
            AccentCard(accentColor: categoryGradient(for: notification.category)[0], padding: 14) {
                HStack(alignment: .top, spacing: 12) {
                    GradientIconTile(systemName: icon(for: notification.category), colors: categoryGradient(for: notification.category), diameter: 38, symbolSize: 17)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top) {
                            Text(notification.title)
                                .font(.limu(size: 13, weight: notification.isUnread ? .bold : .semibold))
                                .foregroundStyle(LimuColors.ink)
                            Spacer(minLength: 8)
                            if notification.isUnread { Circle().fill(LimuColors.copper).frame(width: 8, height: 8).padding(.top, 3) }
                        }
                        Text(notification.message)
                            .font(.limu(size: 12))
                            .foregroundStyle(LimuColors.secondary)
                            .lineSpacing(2)
                        HStack {
                            Text(notification.timestamp).font(.limu(size: 10)).foregroundStyle(LimuColors.muted)
                            Spacer()
                            Text(notification.category)
                                .font(.limu(size: 10, weight: .bold))
                                .foregroundStyle(LimuColors.copper)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(categoryBackground(notification.category))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            if notification.isUnread {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LimuColors.copper)
                    .frame(width: 3)
                    .padding(.vertical, 2)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Cargo": "shippingbox.fill"
        case "Order Form", "Order": "list.clipboard.fill"
        case "Invoice": "doc.text.fill"
        case "Payment": "creditcard.fill"
        case "Shipment": "ferry.fill"
        case "KYC", "Profile": "checklist.checked"
        default: "gearshape.fill"
        }
    }

    /// Matches Android's NotificationCard categoryGradient — the icon tile's gradient, and (as
    /// its first stop) the new AccentCard's top-edge accent colour.
    private func categoryGradient(for category: String) -> [Color] {
        switch category {
        case "Payment": [LimuColors.success, Color(hex: "22C55E")]
        case "Invoice": [LimuColors.danger, Color(hex: "F87171")]
        default: [LimuColors.sunsetOrange, LimuColors.yellow]
        }
    }

    private func categoryBackground(_ category: String) -> Color {
        switch category {
        case "Order Form", "Order": LimuColors.copperWash
        case "Payment": LimuColors.successWash
        case "Invoice": LimuColors.dangerWash
        default: LimuColors.copperWash
        }
    }
}
