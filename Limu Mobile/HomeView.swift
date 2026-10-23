import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    let notifications: [AppNotification]
    let onNavigate: (AppTab) -> Void
    let onNotifications: () -> Void
    let onOpenKYC: () -> Void

    private var activeCargo: [Cargo] { appState.cargo.filter { !["Collected", "Completed"].contains($0.status) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                greetingCard
                homeSections
                Color.clear.frame(height: 24)
            }
        }
        .refreshable { await appState.refreshHome() }
        .background(LimuColors.pageBackground)
        .task { await appState.refreshHome() }
    }

    private var homeSections: some View {
        VStack(spacing: 0) {
            if appState.hasCompletedKYC {
                homeSection("Active Cargo", seeAll: { onNavigate(.cargo) }) {
                    ForEach(activeCargo) { cargo in
                        Button { onNavigate(.cargo) } label: { cargoPreview(cargo) }
                            .buttonStyle(.plain)
                    }
                }
                if let shipment = appState.shipments.first(where: { $0.status == "In Transit" }) ?? appState.shipments.first {
                    homeSection("Shipment Update", seeAll: { onNavigate(.shipments) }) {
                        Button { onNavigate(.shipments) } label: { shipmentPreview(shipment) }
                            .buttonStyle(.plain)
                    }
                }
                homeSection("Order Forms", seeAll: { onNavigate(.orderForms) }) {
                    ForEach(appState.orderForms.prefix(2)) { orderForm in
                        Button { onNavigate(.orderForms) } label: { orderFormPreview(orderForm) }
                            .buttonStyle(.plain)
                    }
                }
            } else {
                kycUnlockCard
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
            }
            homeSection("Notifications", seeAll: onNotifications) {
                ForEach(notifications.filter(\.isUnread).prefix(2)) { notification in
                    notificationPreview(notification)
                }
            }
        }
    }

    private var kycUnlockCard: some View {
        Button(action: onOpenKYC) {
            LimuCard(padding: 16) {
                HStack(spacing: 14) {
                    BrandCircleSymbol(systemName: "lock.shield", diameter: 44, symbolSize: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Unlock your logistics")
                            .font(.limu(size: 14, weight: .bold))
                            .foregroundStyle(LimuColors.ink)
                        Text("Complete KYC once to access cargo, shipments, and order forms.")
                            .font(.limu(size: 12))
                            .foregroundStyle(LimuColors.secondary)
                            .lineSpacing(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.limu(size: 13, weight: .bold))
                        .foregroundStyle(LimuColors.copper)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    private var greetingCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting.uppercased())
                    .font(.limu(size: 12, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.88))
                Text(displayName)
                    .font(.limu(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !businessName.isEmpty {
                    Text(businessName)
                        .font(.limu(size: 14))
                        .foregroundStyle(.white.opacity(0.82))
                }
                HStack(spacing: 10) {
                    statChip(value: "\(activeCargoCount)", label: "Active Cargo")
                    statChip(value: "\(pickupCount)", label: "For Pickup")
                    statChip(value: "\(shipmentCount)", label: "Total Shipments")
                }
                .padding(.top, 16)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "FA9E2D"), LimuColors.sunsetOrange, Color(hex: "E1780A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    CargoWavePattern()
                }
            }

            if !appState.hasCompletedKYC {
                kycStrip
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: LimuColors.sunsetOrange.opacity(0.3), radius: 12, y: 5)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.limu(size: 19, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label.uppercased())
                .font(.limu(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background(.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        }
    }

    private var kycStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.limu(size: 16, weight: .semibold))
                .foregroundStyle(LimuColors.warning)
            Text("KYC verification pending")
                .font(.limu(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "7C4A03"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Button(action: onOpenKYC) {
                Text("Resume")
                    .font(.limu(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(LimuColors.copper)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "FBF1E4"))
    }

    private var displayName: String {
        guard let profile = appState.profile else { return "Limu Client" }
        let first = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return first.isEmpty ? profile.fullName : first
    }

    private var businessName: String {
        appState.profile?.businessName ?? ""
    }

    private var activeCargoCount: Int {
        appState.dashboard?.metrics.activeCargoCount ?? activeCargo.count
    }

    private var pickupCount: Int {
        appState.dashboard?.metrics.readyForCollectionCount ?? appState.cargo.filter(\.readyForCollection).count
    }

    private var shipmentCount: Int {
        appState.shipments.count
    }

    private func homeSection<Content: View>(_ title: String, seeAll: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionAccentBar()
                Text(title)
                    .font(.limu(size: 13, weight: .bold))
                    .foregroundStyle(LimuColors.ink)
                Spacer()
                Button("See all", action: seeAll)
                    .font(.limu(size: 12, weight: .semibold))
                    .foregroundStyle(LimuColors.copper)
                    .buttonStyle(.plain)
            }
            VStack(spacing: 8) { content() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private func cargoPreview(_ cargo: Cargo) -> some View {
        AccentCard(accentColor: statusAccentColor(cargo.status)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cargo.id).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                    Text(cargo.summary).font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                }
                Spacer()
                StatusBadge(status: cargo.status)
            }
            VStack(alignment: .leading, spacing: 8) {
                IconText(icon: "mappin", text: cargo.location)
                HStack(spacing: 12) {
                    IconText(icon: "shippingbox", text: "\(cargo.packages) pkgs")
                    IconText(icon: "scalemass", text: "\(cargo.weight.formatted()) kg")
                    IconText(icon: "cube.transparent", text: "\(cargo.volume.formatted()) CBM")
                }
            }
            .padding(.top, 10)
            HStack {
                Text("Finance:").font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                Spacer()
                StatusBadge(status: cargo.financeStatus)
            }
            .padding(.top, 8)
            .overlay(alignment: .top) { Rectangle().fill(LimuColors.softCream).frame(height: 1) }
        }
    }

    private func shipmentPreview(_ shipment: Shipment) -> some View {
        AccentCard(accentColor: statusAccentColor(shipment.status)) {
            HStack {
                Text(shipment.name).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                Spacer()
                StatusBadge(status: shipment.status)
            }
            HStack(spacing: 12) {
                IconText(icon: "ferry", text: shipment.mode)
                IconText(icon: "mappin", text: shipment.location)
            }
            .padding(.vertical, 10)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEPARTURE").font(.limu(size: 10, weight: .semibold)).foregroundStyle(LimuColors.muted)
                    Text(shipment.departure).font(.limu(size: 12, weight: .bold))
                }
                HStack(spacing: 0) {
                    Capsule().fill(LimuColors.copper).frame(height: 2)
                    Circle().fill(LimuColors.copper).frame(width: 8, height: 8)
                    Capsule().fill(LimuColors.peach).frame(height: 2)
                }
                .padding(.horizontal, 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ARRIVAL").font(.limu(size: 10, weight: .semibold)).foregroundStyle(LimuColors.muted)
                    Text(shipment.arrival).font(.limu(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(LimuColors.ink)
            .padding(10)
            .background(LimuColors.softCream)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func orderFormPreview(_ orderForm: OrderForm) -> some View {
        AccentCard(accentColor: statusAccentColor(orderForm.status)) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(orderForm.id).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                    Text("\(orderForm.orderDate) · \(orderForm.itemCount) items").font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(MockData.money(orderForm.grandTotal, currency: orderForm.currency))
                        .font(.limu(size: 15, weight: .bold))
                        .foregroundStyle(LimuColors.copper)
                    StatusBadge(status: orderForm.status)
                }
            }
        }
    }

    private func notificationPreview(_ notification: AppNotification) -> some View {
        AccentCard(accentColor: LimuColors.copper, padding: 14) {
            HStack(alignment: .top, spacing: 10) {
                GradientIconTile(systemName: "bell.fill", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 30, symbolSize: 13)
                VStack(alignment: .leading, spacing: 3) {
                    Text(notification.title).font(.limu(size: 12, weight: .bold)).foregroundStyle(LimuColors.ink)
                    Text(notification.message).font(.limu(size: 11)).foregroundStyle(LimuColors.secondary).lineSpacing(2)
                    Text(notification.timestamp).font(.limu(size: 10)).foregroundStyle(LimuColors.muted)
                }
            }
        }
    }
}
