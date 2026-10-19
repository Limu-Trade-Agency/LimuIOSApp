import SwiftUI

struct CargoView: View {
    @EnvironmentObject private var appState: AppState
    var hubSegment: Binding<String>?
    private enum Screen { case list, detail, package }

    @State private var selectedCargo: Cargo?
    @State private var selectedPackage: CargoPackage?
    @State private var packages: [CargoPackage] = []
    @State private var timeline: [TimelineEvent] = []
    @State private var loadingDetail = false
    @State private var filter = "All"
    @State private var search = ""

    private let filters = ["All", "Active", "Ready for Collection", "Collected", "Payment Pending"]

    private func matchesFilter(_ cargo: Cargo, filter: String) -> Bool {
        switch filter {
        case "Active": ["In Warehouse", "In Transit", "Loading"].contains { $0.caseInsensitiveCompare(cargo.status) == .orderedSame }
        case "Ready for Collection": cargo.readyForCollection
        case "Collected": cargo.status.caseInsensitiveCompare("Collected") == .orderedSame
        case "Payment Pending": cargo.financeStatus.localizedCaseInsensitiveContains("pending")
        default: true
        }
    }

    private var filterCounts: [String: Int] {
        Dictionary(uniqueKeysWithValues: filters.map { name in
            (name, appState.cargo.count { matchesFilter($0, filter: name) })
        })
    }

    private var filteredCargo: [Cargo] {
        appState.cargo.filter { cargo in
            let searchMatches = search.isEmpty || cargo.id.localizedCaseInsensitiveContains(search) || cargo.summary.localizedCaseInsensitiveContains(search)
            return matchesFilter(cargo, filter: filter) && searchMatches
        }
    }

    var body: some View {
        NavigationStack {
            listView
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $selectedCargo) { cargo in
                    CargoDetailView(
                        cargo: cargo,
                        packages: packages,
                        timelineEvents: timeline,
                        loadingDetail: loadingDetail,
                        onBack: { selectedCargo = nil },
                        onPackage: { selectedPackage = $0 }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(item: $selectedPackage) { package in
                        PackageDetailView(package: package) { selectedPackage = nil }
                            .toolbar(.hidden, for: .navigationBar)
                    }
                }
        }
        .task { await appState.refreshCargo() }
    }

    private func openCargo(_ cargo: Cargo) {
        packages = []
        timeline = []
        loadingDetail = true
        selectedCargo = cargo
        Task {
            defer { loadingDetail = false }
            do {
                let detail = try await appState.fetchCargoDetail(cargo.apiID)
                guard selectedCargo?.apiID == cargo.apiID else { return }
                selectedCargo = detail.0
                packages = detail.1
                timeline = detail.2
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            PageHeader {
                HStack(spacing: 12) {
                    Text("My Cargo")
                        .font(.limu(size: 18, weight: .bold))
                    Spacer()
                    BrandCircleSymbol(systemName: "shippingbox.fill", diameter: 40, symbolSize: 17)
                }
                .padding(.bottom, 12)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.limu(size: 14))
                        .foregroundStyle(LimuColors.muted)
                    TextField("Search tracking number…", text: $search)
                        .font(.limu(size: 13))
                        .foregroundStyle(LimuColors.ink)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(LimuColors.softCream)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if let hubSegment {
                SegmentedTabs(items: shipmentsHubSegments, selection: hubSegment)
            }
            FilterStrip(items: filters, selection: $filter, counts: filterCounts)
            ScrollView {
                LazyVStack(spacing: 10) {
                    if filteredCargo.isEmpty {
                        VStack(spacing: 12) {
                            GradientIconTile(systemName: "shippingbox", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 108, symbolSize: 40)
                            Text("No cargo matches this filter.")
                                .font(.limu(size: 14, weight: .semibold))
                                .foregroundStyle(LimuColors.muted)
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(filteredCargo) { cargo in
                            Button {
                                openCargo(cargo)
                            } label: {
                                cargoCard(cargo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .refreshable { await appState.refreshCargo() }
        }
        .background(LimuColors.cream)
    }

    private func costEstimate(for cargo: Cargo) -> CargoCostEstimate? {
        guard !cargo.hasFinalizedCharges else { return nil }
        return appState.shipmentPriceList.costEstimate(
            for: cargo,
            shipmentMode: appState.shipments.first { $0.name == cargo.shipmentName }?.mode
        )
    }

    private func cargoCard(_ cargo: Cargo) -> some View {
        AccentCard(accentColor: statusAccentColor(cargo.status)) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cargo.id).font(.limu(size: 14, weight: .bold)).foregroundStyle(LimuColors.ink)
                    Text(cargo.summary).font(.limu(size: 12)).foregroundStyle(LimuColors.secondary)
                }
                Spacer()
                StatusBadge(status: cargo.status)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    IconText(icon: "mappin", text: cargo.location)
                    IconText(icon: "shippingbox", text: "\(cargo.packages) packages")
                }
                HStack(spacing: 12) {
                    IconText(icon: "scalemass", text: "\(cargo.weight.formatted()) kg")
                    IconText(icon: "cube.transparent", text: "\(cargo.volume.formatted()) CBM")
                }
                if let estimate = costEstimate(for: cargo) {
                    HStack(spacing: 12) {
                        if let shipping = estimate.shipping {
                            IconText(icon: "shippingbox.fill", text: "Est. shipping \(shipping.amountDisplay)")
                        }
                        if let customs = estimate.customs {
                            IconText(icon: "doc.text.fill", text: "Est. customs \(customs.amountDisplay)")
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            HStack {
                Text(cargo.shipmentName).font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                Spacer()
                StatusBadge(status: cargo.financeStatus)
            }
            .padding(.top, 8)
            .overlay(alignment: .top) { Rectangle().fill(LimuColors.softCream).frame(height: 1) }
            if let location = cargo.collectionLocation, cargo.readyForCollection {
                Label("Ready at \(location)", systemImage: "mappin.and.ellipse")
                    .font(.limu(size: 11, weight: .semibold))
                    .foregroundStyle(LimuColors.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LimuColors.successWash)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "86EFAC")) }
                    .padding(.top, 8)
            }
        }
    }
}

private struct CargoDetailView: View {
    @EnvironmentObject private var appState: AppState
    let cargo: Cargo
    let packages: [CargoPackage]
    let timelineEvents: [TimelineEvent]
    let loadingDetail: Bool
    let onBack: () -> Void
    let onPackage: (CargoPackage) -> Void
    @State private var tab = "Overview"

    private var costEstimate: CargoCostEstimate? {
        guard !cargo.hasFinalizedCharges else { return nil }
        return appState.shipmentPriceList.costEstimate(
            for: cargo,
            shipmentMode: appState.shipments.first { $0.name == cargo.shipmentName }?.mode
        )
    }

    private var loadingCard: some View {
        LimuCard {
            HStack(spacing: 10) {
                ProgressView().tint(LimuColors.copper)
                Text("Loading latest details…")
                    .font(.limu(size: 12, weight: .semibold))
                    .foregroundStyle(LimuColors.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Cargo", title: cargo.id, subtitle: cargo.summary, status: cargo.status, onBack: onBack)
            SegmentedTabs(items: ["Overview", "Timeline", "Packages"], selection: $tab)
            ScrollView {
                Group {
                    switch tab {
                    case "Timeline": timeline
                    case "Packages": packagesView
                    default: overview
                    }
                }
                .padding(16)
            }
        }
        .background(LimuColors.cream)
    }

    private var overview: some View {
        VStack(spacing: 12) {
            SectionCard("Cargo Summary") {
                DetailRow(label: "Tracking #", value: cargo.id, monospaced: true)
                DetailRow(label: "Location", value: cargo.location)
                DetailRow(label: "Packages", value: "\(cargo.packages) (\(cargo.checkedPackages) checked)")
                DetailRow(label: "Weight", value: "\(cargo.weight.formatted()) kg")
                DetailRow(label: "Volume", value: "\(cargo.volume.formatted()) CBM")
                DetailRow(label: "Shipment", value: cargo.shipmentName)
                DetailRow(label: "Created", value: cargo.createdAt)
            }
            if let estimate = costEstimate {
                SectionCard("Estimated Costs") {
                    if let shipping = estimate.shipping {
                        estimateRow(title: "Est. Shipping", line: shipping)
                    }
                    if let customs = estimate.customs {
                        estimateRow(title: "Est. Customs", line: customs)
                    }
                    Label("Guidance from the live price list. Final charges follow your invoice.", systemImage: "info.circle")
                        .font(.limu(size: 11))
                        .foregroundStyle(LimuColors.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
            SectionCard("Finance & Payment") {
                HStack {
                    Text("Payment Status").font(.limu(size: 13)).foregroundStyle(Color(hex: "374151"))
                    Spacer()
                    StatusBadge(status: cargo.financeStatus, medium: true)
                }
                if cargo.financeStatus == "Payment Pending" {
                    Label("Payment is handled from the related order form once available.", systemImage: "list.clipboard")
                        .font(.limu(size: 12, weight: .semibold))
                        .foregroundStyle(LimuColors.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(hex: "FFFBEB"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 12)
                } else if cargo.financeStatus == "Approved" {
                    Label("Payment confirmed and approved", systemImage: "checkmark.circle.fill")
                        .font(.limu(size: 12, weight: .semibold))
                        .foregroundStyle(LimuColors.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(LimuColors.successWash)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 12)
                }
            }
            if let location = cargo.collectionLocation, cargo.readyForCollection {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Ready for Collection", systemImage: "checkmark.circle.fill")
                        .font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.success)
                    Text(location).font(.limu(size: 12)).foregroundStyle(Color(hex: "374151"))
                    Text("Bring your ID and tracking number").font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LimuColors.successWash)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "86EFAC"), lineWidth: 1.5) }
            }
            if let notes = cargo.notes {
                SectionCard("Notes") {
                    Text(notes).font(.limu(size: 13)).foregroundStyle(Color(hex: "374151")).lineSpacing(3)
                }
            }
        }
    }

    private func estimateRow(title: String, line: CargoCostEstimate.Line) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.limu(size: 12))
                    .foregroundStyle(LimuColors.secondary)
                Spacer(minLength: 8)
                Text(line.amountDisplay)
                    .font(.limu(size: 13, weight: .bold))
                    .foregroundStyle(LimuColors.ink)
            }
            Text(line.basis)
                .font(.limu(size: 10))
                .foregroundStyle(LimuColors.muted)
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LimuColors.softCream).frame(height: 1)
        }
        .padding(.bottom, 8)
    }

    private var timeline: some View {
        Group {
            if loadingDetail && timelineEvents.isEmpty {
                loadingCard
            } else {
                LimuCard {
                    VStack(spacing: 0) {
                        ForEach(Array(timelineEvents.enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 4) {
                                    Circle().fill(index == 0 ? LimuColors.copper : LimuColors.divider).frame(width: 10, height: 10).padding(.top, 3)
                                    if index < timelineEvents.count - 1 {
                                        Rectangle().fill(LimuColors.peach).frame(width: 2).frame(maxHeight: .infinity)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                                    Text(event.description).font(.limu(size: 12)).foregroundStyle(LimuColors.secondary)
                                    Text(event.timestamp).font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                                }
                                .padding(.bottom, index < timelineEvents.count - 1 ? 18 : 0)
                                Spacer()
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                            Text(event.description).font(.limu(size: 12)).foregroundStyle(LimuColors.secondary)
                            Text(event.timestamp).font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var packagesView: some View {
        VStack(spacing: 10) {
            if loadingDetail && packages.isEmpty {
                loadingCard
            }
            ForEach(packages) { package in
                Button { onPackage(package) } label: {
                    AccentCard(accentColor: LimuColors.success, padding: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(package.content).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                                Text("\(package.code) · \(package.type)").font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                            }
                            Spacer()
                            Text("\(package.checked)/\(package.total)")
                                .font(.limu(size: 11, weight: .bold)).foregroundStyle(LimuColors.success)
                                .padding(.horizontal, 8).padding(.vertical, 5).background(LimuColors.successWash).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        HStack(spacing: 12) {
                            IconText(icon: "number", text: "Qty: \(package.quantity)")
                            IconText(icon: "mail", text: package.courierTracking)
                        }
                        .padding(.vertical, 10)
                        Text("CHECKED PROGRESS").font(.limu(size: 10, weight: .semibold)).foregroundStyle(LimuColors.muted)
                        ProgressView(value: Double(package.checked), total: Double(max(package.total, 1))).tint(Color(hex: "22C55E"))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PackageDetailView: View {
    let package: CargoPackage
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Packages", title: package.content, subtitle: package.code, onBack: onBack)
            ScrollView {
                VStack(spacing: 12) {
                    SectionCard("Package Info") {
                        DetailRow(label: "Package Code", value: package.code, monospaced: true)
                        DetailRow(label: "Package Type", value: package.type)
                        DetailRow(label: "Quantity", value: "\(package.quantity)")
                        DetailRow(label: "Courier Tracking", value: package.courierTracking, monospaced: true)
                        DetailRow(label: "Checked At", value: package.checkedAt)
                    }
                    if let imageURL = package.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            case .failure:
                                Label("Photo could not be loaded", systemImage: "photo")
                                    .font(.limu(size: 12)).foregroundStyle(LimuColors.muted)
                                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                            default:
                                ProgressView().tint(LimuColors.copper).frame(maxWidth: .infinity).padding(.vertical, 40)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(LimuColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: LimuColors.charcoal.opacity(0.06), radius: 5, y: 2)
                    }
                    SectionCard("Units Checked") {
                        HStack {
                            Text("Checked at the warehouse").font(.limu(size: 13)).foregroundStyle(Color(hex: "374151"))
                            Spacer()
                            Text("\(package.checked) / \(package.total)").font(.limu(size: 15, weight: .heavy)).foregroundStyle(LimuColors.success)
                        }
                        ProgressView(value: Double(package.checked), total: Double(max(package.total, 1)))
                            .tint(Color(hex: "22C55E"))
                            .padding(.top, 10)
                        HStack(spacing: 10) {
                            Image(systemName: package.isChecked ? "checkmark.circle.fill" : "circle")
                                .font(.limu(size: 20))
                                .foregroundStyle(package.isChecked ? LimuColors.success : LimuColors.muted)
                            Text(package.isChecked ? "Warehouse check complete" : "Awaiting warehouse check")
                                .font(.limu(size: 13, weight: .semibold))
                                .foregroundStyle(package.isChecked ? LimuColors.ink : LimuColors.muted)
                            Spacer()
                        }
                        .padding(.top, 14)
                    }
                }
                .padding(16)
            }
        }
        .background(LimuColors.cream)
    }
}
