import SwiftUI

/// Shipments and cargo are two views of the same goods, so they share one tab with a switch at the top.
let shipmentsHubSegments = ["Shipments", "Cargo"]

struct ShipmentsHubView: View {
    @Binding var segment: String

    var body: some View {
        if segment == "Cargo" {
            CargoView(hubSegment: $segment)
        } else {
            ShipmentsView(hubSegment: $segment)
        }
    }
}

struct ShipmentsView: View {
    @EnvironmentObject private var appState: AppState
    var hubSegment: Binding<String>?
    @State private var filter = "All"
    @State private var selectedShipment: Shipment?
    @State private var updates: [ShipmentUpdate] = []
    @State private var shipmentCargo: [Cargo] = []
    private let filters = ["All", "Active", "Upcoming", "Completed"]

    private var filtered: [Shipment] {
        appState.shipments.filter { shipment in
            switch filter {
            case "Active": ["In Transit", "Loading"].contains(shipment.status)
            case "Upcoming": shipment.status == "Upcoming"
            case "Completed": shipment.status == "Completed"
            default: true
            }
        }
    }

    var body: some View {
        if let selectedShipment {
            ShipmentDetailView(shipment: selectedShipment, updates: updates, cargo: shipmentCargo) { self.selectedShipment = nil }
        } else {
            VStack(spacing: 0) {
                AppHeader {
                    Text("My Shipments")
                        .font(.limu(size: 18, weight: .bold))
                    Text("Shipments containing your cargo")
                        .font(.limu(size: 12))
                        .foregroundStyle(LimuColors.peach)
                        .padding(.top, 2)
                }
                if let hubSegment {
                    SegmentedTabs(items: shipmentsHubSegments, selection: hubSegment)
                }
                FilterStrip(items: filters, selection: $filter)
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filtered.isEmpty {
                            VStack(spacing: 10) {
                                GradientIconTile(systemName: "ferry", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 108, symbolSize: 40)
                                Text("No shipments in this group")
                                    .font(.limu(size: 14, weight: .semibold))
                                    .foregroundStyle(LimuColors.muted)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(filtered) { shipment in
                                Button {
                                    selectedShipment = shipment
                                    Task {
                                        do {
                                            let detail = try await appState.fetchShipmentDetail(shipment.apiID)
                                            selectedShipment = detail.0
                                            updates = detail.1
                                            shipmentCargo = detail.2
                                        } catch {
                                            appState.errorMessage = error.localizedDescription
                                        }
                                    }
                                } label: { shipmentCard(shipment) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(LimuColors.cream)
            .task { await appState.refreshShipments() }
        }
    }

    private func shipmentCard(_ shipment: Shipment) -> some View {
        AccentCard(accentColor: statusAccentColor(shipment.status)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shipment.name).font(.limu(size: 14, weight: .bold)).foregroundStyle(LimuColors.ink)
                    Text("\(shipment.mode) · \(shipment.cargoCount) cargo, \(shipment.packageCount) packages")
                        .font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                }
                Spacer(minLength: 8)
                StatusBadge(status: shipment.status)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEPARTURE").font(.limu(size: 10, weight: .bold)).foregroundStyle(LimuColors.muted)
                    Text(shipment.departure).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                }
                HStack(spacing: 5) {
                    Capsule().fill(LimuColors.peach).frame(height: 2)
                    Image(systemName: "ferry.fill").font(.limu(size: 14)).foregroundStyle(LimuColors.copper)
                    Capsule().fill(shipment.status == "Completed" ? Color(hex: "22C55E") : LimuColors.peach).frame(height: 2)
                }
                .padding(.horizontal, 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ARRIVAL").font(.limu(size: 10, weight: .bold)).foregroundStyle(LimuColors.muted)
                    Text(shipment.arrival).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(LimuColors.softCream)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.vertical, 10)
            IconText(icon: "mappin", text: shipment.location)
        }
    }
}

private struct ShipmentDetailView: View {
    let shipment: Shipment
    let updates: [ShipmentUpdate]
    let cargo: [Cargo]
    let onBack: () -> Void
    @State private var tab = "Overview"

    private var progress: Double { shipment.progress }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Shipments", title: shipment.name, subtitle: shipment.mode, status: shipment.status, onBack: onBack)
            SegmentedTabs(items: ["Overview", "Updates"], selection: $tab)
            ScrollView {
                Group {
                    if tab == "Overview" { overview } else { updatesView }
                }
                .padding(16)
            }
        }
        .background(LimuColors.cream)
    }

    private var overview: some View {
        VStack(spacing: 12) {
            SectionCard("Shipment Summary") {
                DetailRow(label: "Mode", value: shipment.mode)
                DetailRow(label: "Departure", value: shipment.departure)
                DetailRow(label: "Arrival (ETA)", value: shipment.arrival)
                DetailRow(label: "Current Location", value: shipment.location)
                DetailRow(label: "Your Cargo", value: "\(cargo.count) items, \(shipment.packageCount) packages")
            }
            SectionCard("Transit Progress") {
                HStack {
                    Text("Origin")
                    Spacer()
                    Text("Destination")
                }
                .font(.limu(size: 11))
                .foregroundStyle(LimuColors.secondary)
                ProgressView(value: progress)
                    .tint(shipment.status == "Completed" ? Color(hex: "22C55E") : LimuColors.copper)
                    .padding(.vertical, 8)
                Text(shipment.status == "Completed" ? "Delivered" : shipment.status == "Loading" ? "Loading at origin port" : "~\(Int(progress * 100))% Complete · ETA \(shipment.arrival)")
                    .font(.limu(size: 12, weight: .semibold))
                    .foregroundStyle(shipment.status == "Completed" ? LimuColors.success : LimuColors.copper)
                    .frame(maxWidth: .infinity)
            }
            if let latest = updates.first {
                Button { tab = "Updates" } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LATEST UPDATE")
                            .font(.limu(size: 11, weight: .bold)).tracking(0.7).foregroundStyle(LimuColors.muted)
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(LimuColors.copper).frame(width: 8, height: 8).padding(.top, 4)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(latest.location).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                                Text(latest.message).font(.limu(size: 12)).foregroundStyle(LimuColors.secondary).lineSpacing(2)
                                Text(latest.timestamp).font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                            }
                        }
                        Text("View all \(updates.count) updates →")
                            .font(.limu(size: 12, weight: .semibold)).foregroundStyle(LimuColors.copper)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LimuColors.copperWash)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(LimuColors.peach) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var updatesView: some View {
        LimuCard {
            if updates.isEmpty {
                VStack(spacing: 8) {
                    GradientIconTile(systemName: "tray", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 76, symbolSize: 30)
                    Text("No updates yet").font(.limu(size: 13, weight: .semibold))
                    Text("Check back once the shipment departs.").font(.limu(size: 12)).foregroundStyle(LimuColors.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                Text("SHIPMENT LOG · \(updates.count) ENTRIES")
                    .font(.limu(size: 11, weight: .bold)).tracking(0.7).foregroundStyle(LimuColors.muted)
                    .padding(.bottom, 16)
                ForEach(Array(updates.enumerated()), id: \.element.id) { index, update in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(index == 0 ? LimuColors.copper : LimuColors.divider)
                                .frame(width: 12, height: 12)
                                .overlay { Circle().stroke(index == 0 ? LimuColors.peach : Color(hex: "D1D5DB"), lineWidth: 2) }
                            if index < updates.count - 1 { Rectangle().fill(LimuColors.peach).frame(width: 2, height: 80) }
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top) {
                                Text(update.location).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                                Spacer()
                                StatusBadge(status: update.status)
                            }
                            Text(update.message).font(.limu(size: 12)).foregroundStyle(Color(hex: "4B5563")).lineSpacing(3)
                            Label(update.timestamp, systemImage: "clock")
                                .font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                        }
                    }
                }
            }
        }
    }
}
