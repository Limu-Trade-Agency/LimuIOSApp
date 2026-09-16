import SwiftUI

struct ShipmentsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter = "All"
    @State private var selectedShipment: Shipment?
    @State private var showingPriceList = false
    @State private var updates: [ShipmentUpdate] = []
    @State private var shipmentCargo: [Cargo] = []
    @State private var loadingDetail = false
    private let filters = ["All", "Active", "Upcoming", "Completed"]

    private func matchesFilter(_ shipment: Shipment, filter: String) -> Bool {
        switch filter {
        case "Active": ["In Transit", "Loading"].contains { $0.caseInsensitiveCompare(shipment.status) == .orderedSame }
        case "Upcoming": shipment.status.caseInsensitiveCompare("Upcoming") == .orderedSame
        case "Completed": shipment.status.caseInsensitiveCompare("Completed") == .orderedSame
        default: true
        }
    }

    private var filterCounts: [String: Int] {
        Dictionary(uniqueKeysWithValues: filters.map { name in
            (name, appState.shipments.count { matchesFilter($0, filter: name) })
        })
    }

    private var filtered: [Shipment] {
        appState.shipments.filter { matchesFilter($0, filter: filter) }
    }

    var body: some View {
        NavigationStack {
            listView
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showingPriceList) {
                    ShipmentPriceListView { showingPriceList = false }
                        .toolbar(.hidden, for: .navigationBar)
                }
                .navigationDestination(item: $selectedShipment) { shipment in
                    ShipmentDetailView(
                        shipment: shipment,
                        updates: updates,
                        cargo: shipmentCargo,
                        loadingDetail: loadingDetail
                    ) { selectedShipment = nil }
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .task {
            await appState.refreshShipments()
            await appState.refreshShipmentPriceList()
        }
    }

    private func openShipment(_ shipment: Shipment) {
        updates = []
        shipmentCargo = []
        loadingDetail = true
        selectedShipment = shipment
        Task {
            defer { loadingDetail = false }
            do {
                let detail = try await appState.fetchShipmentDetail(shipment.apiID)
                guard selectedShipment?.apiID == shipment.apiID else { return }
                selectedShipment = detail.0
                updates = detail.1
                shipmentCargo = detail.2
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            PageHeader {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Shipments")
                            .font(.limu(size: 18, weight: .bold))
                        Text("Shipments containing your cargo")
                            .font(.limu(size: 12))
                            .foregroundStyle(LimuColors.secondary)
                    }
                    Spacer()
                    BrandCircleSymbol(systemName: "ferry.fill", diameter: 40, symbolSize: 17)
                }
            }
            FilterStrip(items: filters, selection: $filter, counts: filterCounts)
            ScrollView {
                LazyVStack(spacing: 12) {
                    Button {
                        showingPriceList = true
                    } label: {
                        priceListEntry
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open shipment price list")

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
                            Button { openShipment(shipment) } label: { shipmentCard(shipment) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .refreshable {
                await appState.refreshShipments()
                await appState.refreshShipmentPriceList()
            }
        }
        .background(LimuColors.cream)
    }

    private var priceListEntry: some View {
        LimuCard(padding: 14) {
            HStack(alignment: .center, spacing: 12) {
                BrandCircleSymbol(systemName: "tag.fill", diameter: 42, symbolSize: 16)
                    .background(LimuColors.copperWash)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Shipment Price List")
                        .font(.limu(size: 14, weight: .bold))
                        .foregroundStyle(LimuColors.ink)
                    Text("Customs, shipping, and air cargo rates")
                        .font(.limu(size: 11))
                        .foregroundStyle(LimuColors.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LimuColors.copper)
            }
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

private struct ShipmentPriceListView: View {
    let onBack: () -> Void
    @EnvironmentObject private var appState: AppState
    @State private var category = "Customs Fees"

    private var prices: [ShipmentPriceItem] {
        priceList.items.filter { $0.category == category }
    }

    private var priceList: ShipmentPriceList {
        appState.shipmentPriceList
    }

    private var categories: [String] {
        priceList.sections.isEmpty ? ["Customs Fees"] : priceList.sections
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(
                backTitle: "Shipments",
                title: "Shipment Price List",
                subtitle: "Client shipment rates",
                onBack: onBack
            )
            SegmentedTabs(items: categories, selection: $category)
            ScrollView {
                LazyVStack(spacing: 12) {
                    summaryCard
                    if category == "Shipping Fees" {
                        shippingPolicyCard
                    }
                    if prices.isEmpty {
                        LimuCard {
                            VStack(spacing: 8) {
                                BrandEmptyStateIcon(systemName: "tag", symbolSize: 30)
                                Text("No rates available")
                                    .font(.limu(size: 13, weight: .semibold))
                                    .foregroundStyle(LimuColors.ink)
                                Text("The portal has not published rates for this section yet.")
                                    .font(.limu(size: 12))
                                    .foregroundStyle(LimuColors.muted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    } else {
                        ForEach(prices) { item in
                            ShipmentPriceCard(item: item)
                        }
                    }
                    SectionCard("Billing Notes") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(priceList.notes, id: \.self) { note in
                                PriceNoteRow(note: note)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .refreshable { await appState.refreshShipmentPriceList(showError: true) }
        }
        .background(LimuColors.cream)
        .task {
            await appState.refreshShipmentPriceList(showError: true)
            if !categories.contains(category), let first = categories.first {
                category = first
            }
        }
    }

    private var summaryCard: some View {
        LimuCard(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                BrandCircleSymbol(systemName: summaryIcon, diameter: 44, symbolSize: 17)
                    .background(LimuColors.copperWash)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(summaryTitle)
                        .font(.limu(size: 15, weight: .bold))
                        .foregroundStyle(LimuColors.ink)
                    Text(summarySubtitle)
                        .font(.limu(size: 12))
                        .foregroundStyle(LimuColors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                StatusBadge(status: "Current")
            }
        }
    }

    private var shippingPolicyCard: some View {
        SectionCard("Shipping Policy") {
            DetailRow(label: "Weight threshold", value: "\(priceList.policy.weightThresholdPerCbm.formatted()) kg/CBM")
            DetailRow(label: "Base currency", value: priceList.policy.baseCurrency)
            DetailRow(label: "Exchange rate", value: "1 USD = \(priceList.policy.usdToRmbRate.formatted()) RMB")
            DetailRow(label: "FX source", value: priceList.policy.exchangeRateSource)
            if let asOf = priceList.policy.exchangeRateAsOf, !asOf.isEmpty {
                DetailRow(label: "FX as of", value: LimuDateFormatting.display(asOf))
            }
            if let error = priceList.policy.exchangeRateError, !error.isEmpty {
                PriceNoteRow(note: error)
            }
        }
    }

    private var summaryIcon: String {
        switch category {
        case "Shipping Fees": "ferry.fill"
        case "Air Cargo": "airplane"
        default: "doc.text.fill"
        }
    }

    private var summaryTitle: String {
        switch category {
        case "Shipping Fees": "Shipping Price per CBM"
        case "Air Cargo": "Air Cargo"
        default: "Customs Price per CBM"
        }
    }

    private var summarySubtitle: String {
        switch category {
        case "Shipping Fees":
            return "\(prices.count) rates · \(priceList.policy.baseCurrency) base · \(Int(priceList.policy.weightThresholdPerCbm.rounded())) kg/CBM threshold"
        case "Air Cargo":
            return "\(prices.count) rates shown per kilogram"
        default:
            return "\(prices.count) cargo-category customs rates in \(LimuCurrency.defaultCode)"
        }
    }
}

private struct ShipmentPriceCard: View {
    let item: ShipmentPriceItem

    var body: some View {
        LimuCard(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                BrandCircleSymbol(systemName: item.icon, diameter: 42, symbolSize: 16, patternOpacity: 0.34)
                    .background(categoryWash)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.service)
                        .font(.limu(size: 14, weight: .bold))
                        .foregroundStyle(LimuColors.ink)
                        .lineLimit(2)
                    Text(item.route)
                        .font(.limu(size: 11))
                        .foregroundStyle(LimuColors.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            Text(item.rateDisplay)
                .font(.limu(size: 20, weight: .heavy))
                .foregroundStyle(LimuColors.copper)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LimuColors.softCream)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.vertical, 12)

            VStack(spacing: 8) {
                if let converted = item.convertedRateDisplay {
                    PriceInfoRow(icon: "arrow.left.arrow.right", label: "Approx.", value: converted)
                }
                PriceInfoRow(icon: "calendar", label: "Updated", value: item.updatedDisplay)
                PriceInfoRow(icon: "info.circle", label: "Notes", value: item.note)
            }
        }
    }

    private var categoryWash: Color {
        switch item.category {
        case "Air Cargo":
            Color(hex: "EFF6FF")
        case "Customs Fees":
            LimuColors.successWash
        default:
            LimuColors.copperWash
        }
    }
}

private struct PriceInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LimuColors.copper)
                .frame(width: 18, height: 18)
            Text(label)
                .font(.limu(size: 11, weight: .semibold))
                .foregroundStyle(LimuColors.muted)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.limu(size: 12, weight: .semibold))
                .foregroundStyle(LimuColors.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct PriceNoteRow: View {
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LimuColors.copper)
                .padding(.top, 1)
            Text(note)
                .font(.limu(size: 12))
                .foregroundStyle(LimuColors.secondary)
                .lineSpacing(3)
        }
    }
}

private struct ShipmentDetailView: View {
    let shipment: Shipment
    let updates: [ShipmentUpdate]
    let cargo: [Cargo]
    let loadingDetail: Bool
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
                    if loadingDetail {
                        ProgressView().tint(LimuColors.copper)
                        Text("Loading shipment log…").font(.limu(size: 12, weight: .semibold)).foregroundStyle(LimuColors.secondary)
                    } else {
                        GradientIconTile(systemName: "tray", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 76, symbolSize: 30)
                        Text("No updates yet").font(.limu(size: 13, weight: .semibold))
                        Text("Check back once the shipment departs.").font(.limu(size: 12)).foregroundStyle(LimuColors.muted)
                    }
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
                            if index < updates.count - 1 { Rectangle().fill(LimuColors.peach).frame(width: 2).frame(maxHeight: .infinity) }
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
                        .padding(.bottom, index < updates.count - 1 ? 18 : 0)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
