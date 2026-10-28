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
        .task(id: appState.pendingLink) { await openPendingLink() }
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

    /// A tapped shipment-update notification names one shipment: open it directly, not just the list.
    private func openPendingLink() async {
        guard case .shipment(let id)? = appState.pendingLink else { return }
        appState.pendingLink = nil
        updates = []
        shipmentCargo = []
        loadingDetail = true
        defer { loadingDetail = false }
        do {
            let detail = try await appState.fetchShipmentDetail(id)
            selectedShipment = detail.0
            updates = detail.1
            shipmentCargo = detail.2
        } catch {
            appState.errorMessage = error.localizedDescription
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
                            .padding(.top, 2)
                    }
                    Spacer()
                    BrandCircleSymbol(systemName: "ferry.fill", diameter: 40, symbolSize: 17)
                }
            }
            if let hubSegment {
                SegmentedTabs(items: shipmentsHubSegments, selection: hubSegment)
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
        .background(LimuColors.pageBackground)
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

    /// Shipment number and date lead; the current stage (name, status, estimate, elapsed time) sits underneath.
    /// Full stage detail is one tap away.
    private func shipmentCard(_ shipment: Shipment) -> some View {
        AccentCard(accentColor: statusAccentColor(shipment.status)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shipment.number).font(.limu(size: 14, weight: .bold)).foregroundStyle(LimuColors.ink)
                    Text("\(shipment.mode) · \(shipment.departure) · \(shipment.cargoCount) cargo, \(shipment.packageCount) packages")
                        .font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                }
                Spacer(minLength: 8)
                StatusBadge(status: shipment.status)
            }
            if let stage = shipment.currentStage {
                CurrentStageSnippet(stage: stage, arrival: shipment.arrival)
                    .padding(.top, 10)
            } else {
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
            }
            IconText(icon: "mappin", text: shipment.location)
        }
    }
}

/// The current stage only: name, status, estimated completion, elapsed time against the estimate, and a
/// progress bar. Used on the list card and the top of the shipment overview.
private struct CurrentStageSnippet: View {
    let stage: ShipmentStageSnippet
    var arrival: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("CURRENT STAGE · \(stage.index) OF \(stage.count)")
                    .font(.limu(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(LimuColors.muted)
                Spacer()
                StatusBadge(status: stage.status)
            }
            Text(stage.name).font(.limu(size: 14, weight: .bold)).foregroundStyle(LimuColors.ink)
            if !stage.location.isEmpty {
                Text(stage.location).font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
            }
            ProgressView(value: min(max(stage.progress, 0), 1))
                .tint(stage.status.caseInsensitiveCompare("Delayed") == .orderedSame ? LimuColors.danger : LimuColors.copper)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ELAPSED").font(.limu(size: 9, weight: .bold)).foregroundStyle(LimuColors.muted)
                    Text(LimuDuration.text(minutes: stage.elapsedMinutes)).font(.limu(size: 12, weight: .bold)).foregroundStyle(LimuColors.ink)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("ESTIMATE").font(.limu(size: 9, weight: .bold)).foregroundStyle(LimuColors.muted)
                    Text(LimuDuration.text(minutes: stage.estimatedMinutes)).font(.limu(size: 12, weight: .bold)).foregroundStyle(LimuColors.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("EXPECTED DONE").font(.limu(size: 9, weight: .bold)).foregroundStyle(LimuColors.muted)
                    Text(stage.estimatedCompletion.map { LimuDateFormatting.display($0) } ?? "—")
                        .font(.limu(size: 12, weight: .bold)).foregroundStyle(LimuColors.ink)
                }
            }
            if let comparison = stage.comparison {
                Text(comparison)
                    .font(.limu(size: 11, weight: .semibold))
                    .foregroundStyle((stage.varianceMinutes ?? 0) > 0 ? LimuColors.danger : LimuColors.success)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LimuColors.softCream)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        .background(LimuColors.pageBackground)
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
    /// Stage ids the client has flipped from their default: completed stages start collapsed, the rest start open.
    @State private var toggledStages: Set<Int> = []

    private var progress: Double { shipment.currentStage?.progress ?? shipment.progress }
    private var hasStages: Bool { !shipment.stages.isEmpty }
    // With stages, updates live under each stage (Stages tab), so there is no separate Updates tab.
    private var tabs: [String] { hasStages ? ["Overview", "Stages"] : ["Overview", "Updates"] }

    /// Stage updates (who/what changed, in the shipment's own words) come first, then the older shipment log.
    private var combinedUpdates: [ShipmentUpdate] {
        let stageEntries = shipment.stageUpdates.map {
            ShipmentUpdate(id: "stage-\($0.id)", shipmentID: shipment.id, location: $0.location.isEmpty ? $0.stage : $0.location, status: $0.status, message: $0.message, timestamp: $0.timestamp, actor: "")
        }
        let known = Set(stageEntries.map(\.message))
        return stageEntries + updates.filter { !known.contains($0.message) }
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Shipments", title: shipment.number, subtitle: shipment.mode, status: shipment.status, onBack: onBack)
            SegmentedTabs(items: tabs, selection: $tab)
            ScrollView {
                Group {
                    switch tab {
                    case "Stages": stagesView
                    case "Updates": updatesView
                    default: overview
                    }
                }
                .padding(16)
            }
        }
        .background(LimuColors.pageBackground)
    }

    private var overview: some View {
        VStack(spacing: 12) {
            if let stage = shipment.currentStage {
                CurrentStageSnippet(stage: stage, arrival: shipment.arrival)
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(LimuColors.peach) }
            }
            if hasStages {
                analyticsCard
            }
            SectionCard("Shipment Summary") {
                DetailRow(label: "Shipment", value: shipment.number)
                DetailRow(label: "Date", value: shipment.departure)
                DetailRow(label: "Mode", value: shipment.mode)
                if let plan = shipment.plan, !plan.route.isEmpty {
                    DetailRow(label: "Route", value: plan.route)
                }
                if let plan = shipment.plan, !plan.origin.isEmpty || !plan.destination.isEmpty {
                    DetailRow(label: "From → To", value: [plan.origin, plan.destination].filter { !$0.isEmpty }.joined(separator: " → "))
                }
                DetailRow(label: "Current Location", value: shipment.location)
                DetailRow(label: "Your Cargo", value: "\(cargo.count) items, \(shipment.packageCount) packages")
            }
            if let plan = shipment.plan, plan.estLoadingDate != nil || plan.estArrivalDate != nil || plan.estCollectionDate != nil {
                SectionCard("Estimated Dates") {
                    if let date = plan.estLoadingDate { DetailRow(label: "Loading", value: LimuDateFormatting.display(date)) }
                    if let date = plan.estArrivalDate { DetailRow(label: "Port / airport arrival", value: LimuDateFormatting.display(date)) }
                    if let date = plan.estCollectionDate { DetailRow(label: "Collection", value: LimuDateFormatting.display(date)) }
                    if let days = plan.estTransitDays { DetailRow(label: "Transit", value: "\(days) days") }
                }
            } else {
                SectionCard("Estimated Dates") {
                    DetailRow(label: "Departure", value: shipment.departure)
                    DetailRow(label: "Arrival (ETA)", value: shipment.arrival)
                }
            }
            if !shipment.cargoReferences.isEmpty {
                SectionCard("Cargo in this shipment") {
                    ForEach(shipment.cargoReferences, id: \.self) { reference in
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.fill").font(.limu(size: 12)).foregroundStyle(LimuColors.copper)
                            Text(reference).font(.limu(size: 13, weight: .semibold)).foregroundStyle(LimuColors.ink)
                            Spacer()
                        }
                    }
                }
            }
            SectionCard("Transit Progress") {
                HStack {
                    Text("Origin")
                    Spacer()
                    Text("Destination")
                }
                .font(.limu(size: 11))
                .foregroundStyle(LimuColors.secondary)
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(shipment.status == "Completed" ? Color(hex: "22C55E") : LimuColors.copper)
                    .padding(.vertical, 8)
                Text(shipment.status == "Completed" ? "Delivered" : "~\(Int(progress * 100))% Complete · ETA \(shipment.arrival)")
                    .font(.limu(size: 12, weight: .semibold))
                    .foregroundStyle(shipment.status == "Completed" ? LimuColors.success : LimuColors.copper)
                    .frame(maxWidth: .infinity)
            }
            if let history = shipment.history, !history.stages.isEmpty {
                historyCard(history)
            }
            if let latest = combinedUpdates.first {
                Button { tab = hasStages ? "Stages" : "Updates" } label: {
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
                        Text("View all \(combinedUpdates.count) updates →")
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

    /// How long each stage took on previous shipments of the same mode, to help estimate this one.
    private func historyCard(_ history: ShipmentHistory) -> some View {
        SectionCard("Previous \(shipment.mode.lowercased().contains("air") ? "air" : "sea") shipments") {
            ForEach(history.stages) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.stage).font(.limu(size: 12)).foregroundStyle(LimuColors.secondary)
                    Spacer()
                    Text("avg \(LimuDuration.text(minutes: row.averageMinutes))")
                        .font(.limu(size: 12, weight: .bold)).foregroundStyle(LimuColors.ink)
                }
                .padding(.bottom, 6)
            }
            if let accuracy = history.estimateAccuracy {
                Label("\(Int((accuracy * 100).rounded()))% of stages finished within their estimate", systemImage: "scope")
                    .font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                    .padding(.top, 2)
            }
        }
    }

    /// Overall read of the shipment against its estimates: how many stages were on time or late, and what is expected.
    private var analyticsCard: some View {
        let a = ShipmentAnalyticsCalculator.calculate(shipment)
        return SectionCard("Shipment Analytics") {
            DetailRow(label: "On time", value: "\(a.stagesOnTime) of \(a.totalStages) stages")
            DetailRow(label: "Late", value: "\(a.stagesLate) of \(a.totalStages) stages")
            if let average = a.averageVarianceMinutes {
                DetailRow(label: "Average vs estimate", value: average > 0 ? "\(LimuDuration.text(minutes: average)) late" : "\(LimuDuration.text(minutes: -average)) early")
            }
            if let actual = a.actualMinutes { DetailRow(label: "Time so far", value: LimuDuration.text(minutes: actual)) }
            if let expected = a.expectedMinutes { DetailRow(label: "Planned duration", value: LimuDuration.text(minutes: expected)) }
            if let expectedProgress = a.expectedProgress {
                DetailRow(label: "Expected progress", value: "\(Int((expectedProgress * 100).rounded()))%")
            } else {
                DetailRow(label: "Expected progress", value: "Loading due")
            }
            if let projected = a.projectedArrival { DetailRow(label: "Projected arrival", value: LimuDateFormatting.display(projected)) }
            StageOutcomeBar(outcomes: a.stageOutcomes)
                .padding(.top, 6)
            ForEach(Array(a.delayedStages.enumerated()), id: \.offset) { _, delay in
                Label("\(delay.name): \(delay.reason)", systemImage: "exclamationmark.triangle.fill")
                    .font(.limu(size: 11, weight: .semibold)).foregroundStyle(LimuColors.danger)
            }
        }
    }

    private func isStageOpen(_ stage: ShipmentStage) -> Bool {
        stage.isCompleted ? toggledStages.contains(stage.id) : !toggledStages.contains(stage.id)
    }

    private func toggleStage(_ stage: ShipmentStage) {
        if toggledStages.contains(stage.id) { toggledStages.remove(stage.id) } else { toggledStages.insert(stage.id) }
    }

    private var stagesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SHIPMENT STAGES · \(shipment.stages.count)")
                .font(.limu(size: 11, weight: .bold)).tracking(0.7).foregroundStyle(LimuColors.muted)
                .padding(.bottom, 14)
            ForEach(Array(shipment.stages.enumerated()), id: \.element.id) { index, stage in
                stageRow(stage, isLast: index == shipment.stages.count - 1)
            }
        }
    }

    private func stageRow(_ stage: ShipmentStage, isLast: Bool) -> some View {
        let open = isStageOpen(stage)
        // The API sends newest first; the sub-timeline reads oldest at the top, most recent at the bottom.
        let stageUpdates = Array(shipment.stageUpdates.filter { $0.stage == stage.name }.reversed())
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: stage.isCompleted ? "checkmark.circle.fill" : stage.isCurrent ? "circle.inset.filled" : "circle")
                    .font(.limu(size: 20))
                    .foregroundStyle(stage.isCompleted ? LimuColors.success : stage.isCurrent ? LimuColors.copper : LimuColors.divider)
                    .frame(width: 22, height: 22)
                if !isLast {
                    Rectangle()
                        .fill(stage.isCompleted ? LimuColors.success : LimuColors.yellow)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Button { toggleStage(stage) } label: {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.name + (stage.isOptional ? " (optional)" : ""))
                                .font(.limu(size: 14, weight: .bold))
                                .foregroundStyle(stage.isCompleted ? LimuColors.success : LimuColors.ink)
                            if !stage.location.isEmpty {
                                Text(stage.location).font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                            }
                            if stage.isCompleted {
                                Text("Took \(LimuDuration.text(minutes: stage.durationMinutes))")
                                    .font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                            }
                        }
                        Spacer(minLength: 8)
                        StatusBadge(status: stage.status)
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.limu(size: 11, weight: .bold)).foregroundStyle(LimuColors.muted)
                    }
                    .padding(.horizontal, stage.isCompleted ? 10 : 0)
                    .padding(.vertical, stage.isCompleted ? 8 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(stage.isCompleted ? LimuColors.successWash : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if open {
                    stageTimes(stage)
                    if let reason = stage.delayReason, !reason.isEmpty {
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .font(.limu(size: 11, weight: .semibold)).foregroundStyle(LimuColors.danger)
                    }
                    if !stageUpdates.isEmpty {
                        stageUpdatesView(stageUpdates)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stageUpdatesView(_ updates: [ShipmentStageUpdate]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPDATES · \(updates.count)")
                .font(.limu(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(LimuColors.muted)
            ForEach(Array(updates.enumerated()), id: \.element.id) { index, update in
                let latest = index == updates.count - 1
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(latest ? LimuColors.copper : LimuColors.divider)
                            .frame(width: latest ? 10 : 8, height: latest ? 10 : 8)
                            .padding(.top, 4)
                        if index < updates.count - 1 {
                            Rectangle().fill(LimuColors.yellow).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(update.message).font(.limu(size: 12)).foregroundStyle(Color(hex: "4B5563")).lineSpacing(3)
                        Text(update.timestamp).font(.limu(size: 10)).foregroundStyle(LimuColors.muted)
                    }
                    .padding(.bottom, index < updates.count - 1 ? 10 : 0)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func stageTimes(_ stage: ShipmentStage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let start = stage.startAt { stageTimeRow("Started", LimuDateFormatting.display(start)) }
            if let estimate = stage.estimatedEndAt { stageTimeRow("Expected", LimuDateFormatting.display(estimate)) }
            if let end = stage.endAt { stageTimeRow("Finished", LimuDateFormatting.display(end)) }
            if let minutes = stage.durationMinutes { stageTimeRow("Took", LimuDuration.text(minutes: minutes)) }
        }
    }

    private func stageTimeRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.limu(size: 11)).foregroundStyle(LimuColors.muted).frame(width: 62, alignment: .leading)
            Text(value).font(.limu(size: 11, weight: .semibold)).foregroundStyle(LimuColors.secondary)
        }
    }

    private var updatesView: some View {
        LimuCard {
            if combinedUpdates.isEmpty {
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
                Text("SHIPMENT LOG · \(combinedUpdates.count) ENTRIES")
                    .font(.limu(size: 11, weight: .bold)).tracking(0.7).foregroundStyle(LimuColors.muted)
                    .padding(.bottom, 16)
                ForEach(Array(combinedUpdates.enumerated()), id: \.element.id) { index, update in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(index == 0 ? LimuColors.copper : LimuColors.divider)
                                .frame(width: 12, height: 12)
                                .overlay { Circle().stroke(index == 0 ? LimuColors.peach : Color(hex: "D1D5DB"), lineWidth: 2) }
                            if index < combinedUpdates.count - 1 { Rectangle().fill(LimuColors.peach).frame(width: 2).frame(maxHeight: .infinity) }
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
                        .padding(.bottom, index < combinedUpdates.count - 1 ? 18 : 0)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// One segment per stage, with a legend: green on time, red late, grey done without an estimate, copper in progress.
private struct StageOutcomeBar: View {
    let outcomes: [StageOutcome]

    private func color(_ outcome: StageOutcome) -> Color {
        switch outcome {
        case .onTime: return Color(hex: "22C55E")
        case .late: return LimuColors.danger
        case .done: return Color(hex: "94A3B8")
        case .current: return LimuColors.copper
        case .open: return LimuColors.divider
        }
    }

    var body: some View {
        if outcomes.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(Array(outcomes.enumerated()), id: \.offset) { _, outcome in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(outcome))
                            .frame(height: 10)
                    }
                }
                HStack(spacing: 14) {
                    legend("On time", Color(hex: "22C55E"))
                    legend("Late", LimuColors.danger)
                    legend("Done, no estimate", Color(hex: "94A3B8"))
                    legend("In progress", LimuColors.copper)
                    legend("Not started", LimuColors.divider)
                }
                .font(.limu(size: 10))
                .foregroundStyle(LimuColors.muted)
            }
        }
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}
