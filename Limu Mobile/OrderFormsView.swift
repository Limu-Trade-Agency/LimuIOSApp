import SwiftUI

struct OrderFormsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedOrderForm: OrderForm?
    @State private var loadingDetail = false
    @State private var filter = "All"
    @State private var search = ""

    private let filters = ["All", "Draft", "Client Review", "Pending Payment", "Pending Purchase", "Purchased", "Dormant"]

    private func matchesFilter(_ orderForm: OrderForm, filter: String) -> Bool {
        filter == "All" || orderForm.status.caseInsensitiveCompare(filter) == .orderedSame
    }

    private var filterCounts: [String: Int] {
        Dictionary(uniqueKeysWithValues: filters.map { name in
            (name, appState.orderForms.count { matchesFilter($0, filter: name) })
        })
    }

    private var filteredOrderForms: [OrderForm] {
        appState.orderForms.filter { orderForm in
            let searchMatches = search.isEmpty
                || orderForm.id.localizedCaseInsensitiveContains(search)
                || orderForm.title.localizedCaseInsensitiveContains(search)
                || orderForm.shipmentReference.localizedCaseInsensitiveContains(search)
            return matchesFilter(orderForm, filter: filter) && searchMatches
        }
    }

    private var reviewCount: Int {
        appState.orderForms.filter(\.canClientReview).count
    }

    var body: some View {
        NavigationStack {
            listView
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $selectedOrderForm) { orderForm in
                    OrderFormDetailView(
                        orderForm: orderForm,
                        loadingDetail: loadingDetail,
                        onBack: { selectedOrderForm = nil },
                        onUpdate: { updated in selectedOrderForm = updated }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
        .background(LimuColors.pageBackground)
        .task { await appState.refreshOrderForms() }
    }

    private func openOrderForm(_ orderForm: OrderForm) {
        loadingDetail = true
        selectedOrderForm = orderForm
        Task {
            defer { loadingDetail = false }
            do {
                let detail = try await appState.fetchOrderFormDetail(orderForm.apiID)
                guard selectedOrderForm?.apiID == orderForm.apiID else { return }
                selectedOrderForm = detail
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            PageHeader {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Order Forms")
                            .font(.limu(size: 18, weight: .bold))
                        Text(reviewCount == 1 ? "1 form needs your review" : "\(reviewCount) forms need your review")
                            .font(.limu(size: 12))
                            .foregroundStyle(LimuColors.secondary)
                    }
                    Spacer()
                    GradientIconTile(systemName: "list.clipboard", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 40, symbolSize: 17)
                }
                .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.limu(size: 14))
                        .foregroundStyle(LimuColors.muted)
                    TextField("Search order number, title, shipment…", text: $search)
                        .font(.limu(size: 13))
                        .foregroundStyle(LimuColors.ink)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(LimuColors.softCream)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            FilterStrip(items: filters, selection: $filter, counts: filterCounts)
            ScrollView {
                LazyVStack(spacing: 10) {
                    if filteredOrderForms.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredOrderForms) { orderForm in
                            Button {
                                openOrderForm(orderForm)
                            } label: {
                                orderFormCard(orderForm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .refreshable { await appState.refreshOrderForms() }
        }
        .background(LimuColors.pageBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            GradientIconTile(systemName: "list.clipboard", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 108, symbolSize: 42)
            Text("No order forms here yet")
                .font(.limu(size: 15, weight: .bold))
                .foregroundStyle(LimuColors.ink)
            Text("When the portal shares an order form with you, it will appear here for review and tracking.")
                .font(.limu(size: 12))
                .foregroundStyle(LimuColors.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private func orderFormCard(_ orderForm: OrderForm) -> some View {
        AccentCard(accentColor: statusAccentColor(orderForm.status)) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(orderForm.id)
                        .font(.limu(size: 14, weight: .bold))
                        .foregroundStyle(LimuColors.ink)
                    Text(orderForm.title.isEmpty ? orderForm.shipmentReference.ifEmpty("Order form") : orderForm.title)
                        .font(.limu(size: 12))
                        .foregroundStyle(LimuColors.secondary)
                }
                Spacer()
                StatusBadge(status: orderForm.status)
            }

            HStack(spacing: 12) {
                IconText(icon: "calendar", text: orderForm.orderDate)
                IconText(icon: "shippingbox", text: "\(orderForm.itemCount) items")
                if !orderForm.shipmentReference.isEmpty {
                    IconText(icon: "ferry", text: orderForm.shipmentReference)
                }
            }
            .padding(.vertical, 10)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TOTAL")
                        .font(.limu(size: 10, weight: .semibold))
                        .foregroundStyle(LimuColors.muted)
                    Text(MockData.money(orderForm.grandTotal, currency: orderForm.currency))
                        .font(.limu(size: 16, weight: .heavy))
                        .foregroundStyle(LimuColors.ink)
                }
                Spacer()
                if orderForm.canClientReview {
                    Label("Review needed", systemImage: "hand.tap.fill")
                        .font(.limu(size: 11, weight: .bold))
                        .foregroundStyle(LimuColors.warning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(hex: "FFFBEB"))
                        .clipShape(Capsule())
                } else {
                    Text("\(orderForm.approvedItemCount) approved · \(orderForm.declinedItemCount) declined")
                        .font(.limu(size: 11, weight: .semibold))
                        .foregroundStyle(LimuColors.secondary)
                }
            }
            .padding(.top, 8)
            .overlay(alignment: .top) { Rectangle().fill(LimuColors.softCream).frame(height: 1) }
        }
    }
}

private struct OrderFormDetailView: View {
    @EnvironmentObject private var appState: AppState

    let orderForm: OrderForm
    let loadingDetail: Bool
    let onBack: () -> Void
    let onUpdate: (OrderForm) -> Void

    @State private var tab = "Overview"
    @State private var workingItemID: Int?
    @State private var completingReview = false
    @State private var previewImageURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(
                backTitle: "Order Forms",
                title: orderForm.id,
                subtitle: orderForm.title.isEmpty ? orderForm.orderDate : orderForm.title,
                status: orderForm.status,
                onBack: onBack
            )
            SegmentedTabs(items: ["Overview", "Items", "Tracker"], selection: $tab)
            ScrollView {
                Group {
                    switch tab {
                    case "Items":
                        itemsView
                    case "Tracker":
                        trackerView
                    default:
                        overview
                    }
                }
                .padding(16)
            }
        }
        .background(LimuColors.pageBackground)
        .sheet(isPresented: Binding(
            get: { previewImageURL != nil },
            set: { if !$0 { previewImageURL = nil } }
        )) {
            if let previewImageURL {
                ImagePreviewSheet(url: previewImageURL)
            }
        }
    }

    private var overview: some View {
        VStack(spacing: 12) {
            LimuCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(orderForm.canClientReview ? "REVIEW REQUIRED" : "ORDER TOTAL")
                            .font(.limu(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(orderForm.canClientReview ? LimuColors.warning : LimuColors.muted)
                        Text(MockData.money(orderForm.grandTotal, currency: orderForm.currency))
                            .font(.limu(size: 28, weight: .heavy))
                            .foregroundStyle(LimuColors.ink)
                        Text("\(orderForm.itemCount) items · \(orderForm.orderType) order · \(rateLabel)")
                            .font(.limu(size: 12))
                            .foregroundStyle(LimuColors.secondary)
                    }
                    Spacer()
                    GradientIconTile(
                        systemName: orderForm.canClientReview ? "hand.tap.fill" : "checkmark.seal.fill",
                        colors: orderForm.canClientReview ? [LimuColors.warning, LimuColors.yellow] : [LimuColors.success, Color(hex: "22C55E")],
                        diameter: 46,
                        symbolSize: 20
                    )
                }
                if orderForm.canClientReview {
                    Text("Approve or decline each item. When everything looks right, complete the review so the Limu team can move it to supervisor review.")
                        .font(.limu(size: 12))
                        .foregroundStyle(Color(hex: "7C4A03"))
                        .lineSpacing(3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "FFFBEB"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 14)
                }
            }

            SectionCard("Order Summary") {
                DetailRow(label: "Client", value: orderForm.clientName.ifEmpty("—"))
                DetailRow(label: "Assigned to", value: orderForm.assignedTo.ifEmpty("Pending"))
                DetailRow(label: "Prepared by", value: orderForm.preparedBy.ifEmpty("Team"))
                DetailRow(label: "Shipment", value: orderForm.shipmentReference.ifEmpty("Not assigned"))
                DetailRow(label: "Order Date", value: orderForm.orderDate)
            }

            SectionCard("Cost Breakdown") {
                DetailRow(label: "Products", value: MockData.money(orderForm.totalProductValue, currency: orderForm.currency))
                DetailRow(label: "Local courier", value: MockData.money(orderForm.totalLocalCourier, currency: orderForm.currency))
                DetailRow(label: "Agency fee (\(rateLabel))", value: MockData.money(orderForm.agencyFee, currency: orderForm.currency))
                HStack {
                    Text("Grand Total")
                        .font(.limu(size: 13, weight: .bold))
                        .foregroundStyle(LimuColors.ink)
                    Spacer()
                    Text(MockData.money(orderForm.grandTotal, currency: orderForm.currency))
                        .font(.limu(size: 16, weight: .heavy))
                        .foregroundStyle(LimuColors.copper)
                }
                .padding(.top, 2)
            }

            if orderForm.canClientReview {
                PrimaryButton(title: "Complete Review", loading: completingReview, disabled: completingReview) {
                    completeReview()
                }
            }
        }
    }

    private var itemsView: some View {
        VStack(spacing: 10) {
            if orderForm.items.isEmpty {
                LimuCard {
                    VStack(spacing: 10) {
                        if loadingDetail {
                            ProgressView().tint(LimuColors.copper)
                            Text("Loading items…")
                                .font(.limu(size: 12, weight: .semibold))
                                .foregroundStyle(LimuColors.secondary)
                        } else {
                            GradientIconTile(systemName: "shippingbox", colors: [LimuColors.sunsetOrange, LimuColors.yellow], diameter: 92, symbolSize: 36)
                            Text("No items captured")
                                .font(.limu(size: 14, weight: .bold))
                                .foregroundStyle(LimuColors.ink)
                            Text("The portal order form has no product rows yet.")
                                .font(.limu(size: 12))
                                .foregroundStyle(LimuColors.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                ForEach(orderForm.items) { item in
                    itemCard(item)
                }
            }

            if orderForm.canClientReview {
                PrimaryButton(title: "Complete Review", loading: completingReview, disabled: completingReview) {
                    completeReview()
                }
                .padding(.top, 4)
            }
        }
    }

    private var trackerView: some View {
        VStack(spacing: 12) {
            LimuCard {
                VStack(spacing: 0) {
                    ForEach(Array(orderForm.timeline.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(step.active ? LimuColors.copper : step.reached ? LimuColors.success : LimuColors.divider)
                                    .frame(width: 11, height: 11)
                                    .padding(.top, 3)
                                if index < orderForm.timeline.count - 1 {
                                    Rectangle()
                                        .fill(step.reached ? LimuColors.peach : LimuColors.divider.opacity(0.65))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(step.label)
                                        .font(.limu(size: 13, weight: .bold))
                                        .foregroundStyle(step.reached ? LimuColors.ink : LimuColors.muted)
                                    if step.active {
                                        Text("Current")
                                            .font(.limu(size: 9, weight: .bold))
                                            .foregroundStyle(LimuColors.copper)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(LimuColors.copperWash)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(step.note)
                                    .font(.limu(size: 12))
                                    .foregroundStyle(LimuColors.secondary)
                                    .lineSpacing(2)
                                Text([step.createdAt, step.changedBy].filter { !$0.isEmpty && $0 != "—" }.joined(separator: " · "))
                                    .font(.limu(size: 11))
                                    .foregroundStyle(LimuColors.muted)
                            }
                            .padding(.bottom, index < orderForm.timeline.count - 1 ? 16 : 0)
                            Spacer()
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !orderForm.statusUpdates.isEmpty {
                SectionCard("Status Updates") {
                    VStack(spacing: 0) {
                        ForEach(Array(orderForm.statusUpdates.enumerated()), id: \.element.id) { index, update in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    StatusBadge(status: update.status)
                                    Spacer()
                                    Text(update.createdAt)
                                        .font(.limu(size: 10))
                                        .foregroundStyle(LimuColors.muted)
                                }
                                Text(update.note.ifEmpty("Status updated"))
                                    .font(.limu(size: 12, weight: .semibold))
                                    .foregroundStyle(LimuColors.ink)
                                if !update.changedBy.isEmpty {
                                    Text(update.changedBy)
                                        .font(.limu(size: 11))
                                        .foregroundStyle(LimuColors.secondary)
                                }
                            }
                            .padding(.vertical, index == 0 ? 0 : 12)
                            if index < orderForm.statusUpdates.count - 1 {
                                Rectangle().fill(LimuColors.softCream).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func itemCard(_ item: OrderFormItem) -> some View {
        AccentCard(accentColor: statusAccentColor(item.status), padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    if let url = item.photoURLs.first { previewImageURL = url }
                } label: {
                    Group {
                        if let url = item.photoURLs.first {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.limu(size: 20))
                                        .foregroundStyle(LimuColors.muted)
                                case .empty:
                                    ProgressView().tint(LimuColors.copper)
                                @unknown default:
                                    Image(systemName: "photo")
                                }
                            }
                        } else {
                            Image(systemName: "photo")
                                .font(.limu(size: 20))
                                .foregroundStyle(LimuColors.muted)
                        }
                    }
                    .frame(width: 58, height: 58)
                    .background(LimuColors.softCream)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(item.photoURLs.isEmpty)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(item.productName.ifEmpty("Item"))
                            .font(.limu(size: 13, weight: .bold))
                            .foregroundStyle(LimuColors.ink)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        StatusBadge(status: item.status)
                    }
                    if !item.categoryName.isEmpty {
                        Text(item.categoryName)
                            .font(.limu(size: 11, weight: .semibold))
                            .foregroundStyle(LimuColors.copper)
                    }
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.limu(size: 12))
                            .foregroundStyle(LimuColors.secondary)
                            .lineSpacing(2)
                            .lineLimit(3)
                    }
                }
            }

            HStack(spacing: 12) {
                IconText(icon: "number", text: "Qty \(item.quantity)")
                if !item.size.isEmpty { IconText(icon: "ruler", text: item.size) }
                if !item.trackingNumber.isEmpty { IconText(icon: "mail", text: item.trackingNumber) }
            }
            .padding(.vertical, 10)

            VStack(spacing: 8) {
                moneyRow("Unit cost", item.unitPrice)
                moneyRow("Product value", item.productValue)
                moneyRow("Local courier", item.localShipping)
                HStack {
                    Text("Line total")
                        .font(.limu(size: 12, weight: .bold))
                    Spacer()
                    Text(MockData.money(item.lineTotal, currency: orderForm.currency))
                        .font(.limu(size: 13, weight: .heavy))
                        .foregroundStyle(LimuColors.ink)
                }
            }
            .padding(12)
            .background(LimuColors.softCream)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 10) {
                if let productLink = item.productLink {
                    Link(destination: productLink) {
                        Label("View product", systemImage: "link")
                            .font(.limu(size: 12, weight: .bold))
                            .foregroundStyle(LimuColors.copper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(LimuColors.copperWash)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                if orderForm.canClientReview {
                    decisionButton(title: "Approve", icon: "checkmark", tint: LimuColors.success, wash: LimuColors.successWash, item: item, action: "approve")
                    decisionButton(title: "Decline", icon: "xmark", tint: LimuColors.danger, wash: LimuColors.dangerWash, item: item, action: "decline")
                }
            }
            .padding(.top, 10)
        }
    }

    private func moneyRow(_ label: String, _ amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.limu(size: 12))
                .foregroundStyle(LimuColors.secondary)
            Spacer()
            Text(MockData.money(amount, currency: orderForm.currency))
                .font(.limu(size: 12, weight: .semibold))
                .foregroundStyle(LimuColors.ink)
        }
    }

    private func decisionButton(title: String, icon: String, tint: Color, wash: Color, item: OrderFormItem, action: String) -> some View {
        Button {
            setItemStatus(item, action: action)
        } label: {
            HStack(spacing: 5) {
                if workingItemID == item.apiID {
                    ProgressView().controlSize(.small).tint(tint)
                } else {
                    Image(systemName: icon)
                        .font(.limu(size: 11, weight: .bold))
                }
                Text(title)
                    .font(.limu(size: 12, weight: .bold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(wash)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(item.status.caseInsensitiveCompare(title == "Approve" ? "Approved" : "Declined") == .orderedSame ? tint.opacity(0.45) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(workingItemID != nil || completingReview)
    }

    private var rateLabel: String {
        let value = orderForm.orderTypeRate
        return value.rounded() == value ? "\(Int(value))%" : String(format: "%.1f%%", value)
    }

    private func setItemStatus(_ item: OrderFormItem, action: String) {
        workingItemID = item.apiID
        Task {
            let updated = await appState.setOrderFormItemStatus(orderFormID: orderForm.apiID, itemID: item.apiID, action: action)
            await MainActor.run {
                if let updated { onUpdate(updated) }
                workingItemID = nil
            }
        }
    }

    private func completeReview() {
        completingReview = true
        Task {
            let updated = await appState.completeOrderFormReview(orderFormID: orderForm.apiID)
            await MainActor.run {
                if let updated { onUpdate(updated) }
                completingReview = false
            }
        }
    }
}

private struct ImagePreviewSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LimuColors.charcoal.ignoresSafeArea()
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding()
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 42, weight: .semibold))
                            Text("Could not load image")
                                .font(.limu(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    case .empty:
                        ProgressView()
                            .tint(LimuColors.copper)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(LimuColors.peach)
                }
            }
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
