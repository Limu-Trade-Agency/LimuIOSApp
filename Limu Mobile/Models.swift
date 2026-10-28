import Foundation

enum LimuCurrency {
    static let defaultCode = "MWK"

    static func code(_ value: String? = nil) -> String {
        let cleaned = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return cleaned.isEmpty ? defaultCode : cleaned
    }

    static func money(_ value: Double, currency: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 2
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2
        let amount = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(code(currency)) \(amount)"
    }
}

struct Cargo: Identifiable, Hashable {
    let apiID: Int
    let id: String
    let status: String
    let summary: String
    let packages: Int
    let weight: Double
    let volume: Double
    let location: String
    let financeStatus: String
    let shipmentName: String
    let createdAt: String
    let readyForCollection: Bool
    let collectionLocation: String?
    let notes: String?
    let checkedPackages: Int
    let checklist: [CargoChecklistStep]

    init(
        apiID: Int = 0,
        id: String,
        status: String,
        summary: String,
        packages: Int,
        weight: Double,
        volume: Double,
        location: String,
        financeStatus: String,
        shipmentName: String,
        createdAt: String,
        readyForCollection: Bool,
        collectionLocation: String?,
        notes: String?,
        checkedPackages: Int = 0,
        checklist: [CargoChecklistStep] = []
    ) {
        self.apiID = apiID
        self.id = id
        self.status = status
        self.summary = summary
        self.packages = packages
        self.weight = weight
        self.volume = volume
        self.location = location
        self.financeStatus = financeStatus
        self.shipmentName = shipmentName
        self.createdAt = LimuDateFormatting.display(createdAt)
        self.readyForCollection = readyForCollection
        self.collectionLocation = collectionLocation
        self.notes = notes
        self.checkedPackages = checkedPackages
        self.checklist = checklist
    }

    /// True once real charges exist (invoice issued/settled), at which point
    /// price-list estimates are no longer shown.
    var hasFinalizedCharges: Bool {
        if status.caseInsensitiveCompare("Collected") == .orderedSame { return true }
        let normalized = financeStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized.contains("pending") { return false }
        return normalized.contains("approved")
            || normalized.contains("paid")
            || normalized.contains("cleared")
            || normalized.contains("complete")
    }
}

struct CargoPackage: Identifiable, Hashable {
    let id: String
    let content: String
    let quantity: Int
    let type: String
    let code: String
    let courierTracking: String
    let checkedAt: String
    let total: Int
    let checked: Int
    var imageURL: URL? = nil

    /// Every unit of the package has been checked at the warehouse.
    var isChecked: Bool { total > 0 && checked >= total }

    init(id: String, content: String, quantity: Int, type: String, code: String, courierTracking: String, checkedAt: String, total: Int, checked: Int, imageURL: URL? = nil) {
        self.id = id
        self.content = content
        self.quantity = quantity
        self.type = type
        self.code = code
        self.courierTracking = courierTracking
        self.checkedAt = LimuDateFormatting.display(checkedAt)
        self.total = total
        self.checked = checked
        self.imageURL = imageURL
    }
}

struct TimelineEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let timestamp: String
    let actor: String

    init(id: String, title: String, description: String, timestamp: String, actor: String) {
        self.id = id
        self.title = title
        self.description = description
        self.timestamp = LimuDateFormatting.display(timestamp)
        self.actor = actor
    }
}

struct Shipment: Identifiable, Hashable {
    let apiID: Int
    let id: String
    let name: String
    let status: String
    let mode: String
    let departure: String
    let arrival: String
    let location: String
    let cargoCount: Int
    let packageCount: Int
    let progress: Double
    /// Clients with many cargoes found many tracking numbers confusing: the shipment number and date lead,
    /// and the cargo it contains hang off it.
    let number: String
    let currentStage: ShipmentStageSnippet?
    let stages: [ShipmentStage]
    let stageUpdates: [ShipmentStageUpdate]
    let plan: ShipmentPlan?
    let cargoReferences: [String]
    let history: ShipmentHistory?

    init(
        apiID: Int = 0,
        id: String,
        name: String,
        status: String,
        mode: String,
        departure: String,
        arrival: String,
        location: String,
        cargoCount: Int,
        packageCount: Int,
        progress: Double = 0,
        number: String? = nil,
        currentStage: ShipmentStageSnippet? = nil,
        stages: [ShipmentStage] = [],
        stageUpdates: [ShipmentStageUpdate] = [],
        plan: ShipmentPlan? = nil,
        cargoReferences: [String] = [],
        history: ShipmentHistory? = nil
    ) {
        self.apiID = apiID
        self.id = id
        self.name = name
        self.number = number ?? name
        self.currentStage = currentStage
        self.stages = stages
        self.stageUpdates = stageUpdates
        self.plan = plan
        self.cargoReferences = cargoReferences
        self.history = history
        self.status = status
        self.mode = mode
        self.departure = LimuDateFormatting.display(departure)
        self.arrival = LimuDateFormatting.display(arrival)
        self.location = location
        self.cargoCount = cargoCount
        self.packageCount = packageCount
        self.progress = progress
    }
}

struct ShipmentUpdate: Identifiable, Hashable {
    let id: String
    let shipmentID: String
    let location: String
    let status: String
    let message: String
    let timestamp: String
    let actor: String

    init(id: String, shipmentID: String, location: String, status: String, message: String, timestamp: String, actor: String) {
        self.id = id
        self.shipmentID = shipmentID
        self.location = location
        self.status = status
        self.message = message
        self.timestamp = LimuDateFormatting.display(timestamp)
        self.actor = actor
    }
}

struct ShipmentPricePolicy: Hashable {
    let weightThresholdPerCbm: Double
    let baseCurrency: String
    let counterCurrency: String
    let usdToRmbRate: Double
    let exchangeRateSource: String
    let exchangeRateAsOf: String?
    let exchangeRateError: String?
    let updatedAt: String?
}

struct ShipmentPriceList: Hashable {
    let lastUpdated: String?
    let customsLastUpdated: String?
    let shippingLastUpdated: String?
    let policy: ShipmentPricePolicy
    let items: [ShipmentPriceItem]
    let notes: [String]

    var sections: [String] {
        let preferred = ["Customs Fees", "Shipping Fees", "Air Cargo"]
        let available = Set(items.map(\.category))
        let ordered = preferred.filter { available.contains($0) }
        var seen = Set(ordered)
        let remaining = items.map(\.category).filter { section in
            guard !seen.contains(section) else { return false }
            seen.insert(section)
            return true
        }
        return ordered + remaining
    }
}

struct ShipmentPriceItem: Identifiable, Hashable {
    let id: String
    let category: String
    let service: String
    let route: String
    let rate: Double?
    let currency: String
    let unit: String
    let convertedRate: Double?
    let convertedCurrency: String?
    let updatedAt: String?
    let note: String
    let icon: String
    let ratePrefix: String

    init(
        id: String,
        category: String,
        service: String,
        route: String,
        rate: Double?,
        currency: String = LimuCurrency.defaultCode,
        unit: String,
        convertedRate: Double? = nil,
        convertedCurrency: String? = nil,
        updatedAt: String? = nil,
        note: String,
        icon: String,
        ratePrefix: String = ""
    ) {
        self.id = id
        self.category = category
        self.service = service
        self.route = route
        self.rate = rate
        self.currency = currency
        self.unit = unit
        self.convertedRate = convertedRate
        self.convertedCurrency = convertedCurrency
        self.updatedAt = updatedAt.map { LimuDateFormatting.display($0) }
        self.note = note
        self.icon = icon
        self.ratePrefix = ratePrefix
    }

    var rateDisplay: String {
        guard let rate else { return "Not set" }
        let prefix = ratePrefix.isEmpty ? "" : "\(ratePrefix) "
        return "\(prefix)\(LimuCurrency.money(rate, currency: currency)) / \(unit)"
    }

    var convertedRateDisplay: String? {
        guard let convertedRate, let convertedCurrency else { return nil }
        return "\(LimuCurrency.money(convertedRate, currency: convertedCurrency)) / \(unit)"
    }

    var updatedDisplay: String {
        updatedAt?.isEmpty == false ? updatedAt! : "Not available"
    }
}

struct CargoCostEstimate: Hashable {
    struct Line: Hashable {
        let amount: Double
        let currency: String
        let basis: String

        var amountDisplay: String {
            LimuCurrency.money(amount, currency: currency)
        }
    }

    let shipping: Line?
    let customs: Line?
}

extension ShipmentPriceList {
    /// Client-guidance estimate computed from the live price list. Final
    /// charges always come from the issued invoice.
    func costEstimate(for cargo: Cargo, shipmentMode: String? = nil) -> CargoCostEstimate? {
        let isAir = shipmentMode?.localizedCaseInsensitiveContains("air") == true
        let shipping = isAir ? airShippingEstimate(for: cargo) : seaShippingEstimate(for: cargo)
        let customs = customsEstimate(for: cargo)
        guard shipping != nil || customs != nil else { return nil }
        return CargoCostEstimate(shipping: shipping, customs: customs)
    }

    private func seaShippingEstimate(for cargo: Cargo) -> CargoCostEstimate.Line? {
        guard cargo.volume > 0 else { return nil }
        let tiers = items.filter { $0.category == "Shipping Fees" && $0.rate != nil }
        guard !tiers.isEmpty else { return nil }

        func matches(_ item: ShipmentPriceItem, _ keyword: String) -> Bool {
            item.id.localizedCaseInsensitiveContains(keyword) || item.service.localizedCaseInsensitiveContains(keyword)
        }

        let density = cargo.weight / cargo.volume
        let keyword = density >= policy.weightThresholdPerCbm ? "heavy" : "normal"
        let tier = tiers.first { matches($0, keyword) }
            ?? tiers.first { !matches($0, "dangerous") }
            ?? tiers[0]
        guard let rate = tier.rate else { return nil }
        return CargoCostEstimate.Line(
            amount: rate * cargo.volume,
            currency: tier.currency,
            basis: "\(tier.service) · \(LimuCurrency.money(rate, currency: tier.currency)) / \(tier.unit) × \(cargo.volume.formatted()) CBM"
        )
    }

    private func airShippingEstimate(for cargo: Cargo) -> CargoCostEstimate.Line? {
        guard cargo.weight > 0 else { return nil }
        let rows = items.filter { $0.category == "Air Cargo" && $0.rate != nil }
        let row = rows.first { !$0.service.isEmpty && cargo.summary.localizedCaseInsensitiveContains($0.service) }
            ?? rows.first { $0.service.localizedCaseInsensitiveContains("general") }
            ?? rows.first
        guard let row, let rate = row.rate else { return nil }
        return CargoCostEstimate.Line(
            amount: rate * cargo.weight,
            currency: row.currency,
            basis: "\(row.service) · \(LimuCurrency.money(rate, currency: row.currency)) / \(row.unit) × \(cargo.weight.formatted()) kg"
        )
    }

    private func customsEstimate(for cargo: Cargo) -> CargoCostEstimate.Line? {
        guard cargo.volume > 0 else { return nil }
        let rows = items.filter { $0.category == "Customs Fees" && $0.rate != nil }
        guard !rows.isEmpty else { return nil }

        func contentKeyword(_ service: String) -> String {
            service
                .replacingOccurrences(of: "goods", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let row = rows.first { row in
            let keyword = contentKeyword(row.service)
            return !keyword.isEmpty && cargo.summary.localizedCaseInsensitiveContains(keyword)
        }
            ?? rows.first { $0.service.localizedCaseInsensitiveContains("assorted") }
            ?? rows[0]
        guard let rate = row.rate else { return nil }
        return CargoCostEstimate.Line(
            amount: rate * cargo.volume,
            currency: row.currency,
            basis: "\(row.service) · \(LimuCurrency.money(rate, currency: row.currency)) / \(row.unit) × \(cargo.volume.formatted()) CBM"
        )
    }
}

struct OrderFormItem: Identifiable, Hashable {
    let apiID: Int
    let id: String
    let status: String
    let productName: String
    let categoryName: String
    let description: String
    let productLink: URL?
    let size: String
    let quantity: Int
    let unitPrice: Double
    let productValue: Double
    let localShipping: Double
    let lineTotal: Double
    let trackingNumber: String
    let photoURLs: [URL]
    let createdAt: String

    init(
        apiID: Int = 0,
        id: String,
        status: String,
        productName: String,
        categoryName: String = "",
        description: String = "",
        productLink: URL? = nil,
        size: String = "",
        quantity: Int,
        unitPrice: Double,
        productValue: Double,
        localShipping: Double,
        lineTotal: Double,
        trackingNumber: String = "",
        photoURLs: [URL] = [],
        createdAt: String = "—"
    ) {
        self.apiID = apiID
        self.id = id
        self.status = status
        self.productName = productName
        self.categoryName = categoryName
        self.description = description
        self.productLink = productLink
        self.size = size
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.productValue = productValue
        self.localShipping = localShipping
        self.lineTotal = lineTotal
        self.trackingNumber = trackingNumber
        self.photoURLs = photoURLs
        self.createdAt = LimuDateFormatting.display(createdAt)
    }
}

struct OrderFormStatusUpdate: Identifiable, Hashable {
    let id: String
    let status: String
    let note: String
    let changedBy: String
    let createdAt: String

    init(id: String, status: String, note: String, changedBy: String, createdAt: String) {
        self.id = id
        self.status = status
        self.note = note
        self.changedBy = changedBy
        self.createdAt = LimuDateFormatting.display(createdAt)
    }
}

struct OrderFormTimelineStep: Identifiable, Hashable {
    let id: String
    let label: String
    let reached: Bool
    let active: Bool
    let note: String
    let changedBy: String
    let createdAt: String

    init(id: String, label: String, reached: Bool, active: Bool, note: String, changedBy: String, createdAt: String) {
        self.id = id
        self.label = label
        self.reached = reached
        self.active = active
        self.note = note
        self.changedBy = changedBy
        self.createdAt = LimuDateFormatting.display(createdAt)
    }
}

struct OrderForm: Identifiable, Hashable {
    let apiID: Int
    let id: String
    let title: String
    let status: String
    let orderDate: String
    let createdAt: String
    let orderType: String
    let orderTypeRate: Double
    let currency: String
    let clientName: String
    let assignedTo: String
    let preparedBy: String
    let shipmentReference: String
    let totalProductValue: Double
    let totalLocalCourier: Double
    let agencyFee: Double
    let grandTotal: Double
    let itemCount: Int
    let approvedItemCount: Int
    let declinedItemCount: Int
    let canClientReview: Bool
    let clientViewURL: URL?
    let items: [OrderFormItem]
    let timeline: [OrderFormTimelineStep]
    let statusUpdates: [OrderFormStatusUpdate]

    init(
        apiID: Int = 0,
        id: String,
        title: String = "",
        status: String,
        orderDate: String = "—",
        createdAt: String = "—",
        orderType: String = "Full",
        orderTypeRate: Double = 7,
        currency: String = LimuCurrency.defaultCode,
        clientName: String = "",
        assignedTo: String = "",
        preparedBy: String = "",
        shipmentReference: String = "",
        totalProductValue: Double,
        totalLocalCourier: Double,
        agencyFee: Double,
        grandTotal: Double,
        itemCount: Int,
        approvedItemCount: Int = 0,
        declinedItemCount: Int = 0,
        canClientReview: Bool,
        clientViewURL: URL? = nil,
        items: [OrderFormItem] = [],
        timeline: [OrderFormTimelineStep] = [],
        statusUpdates: [OrderFormStatusUpdate] = []
    ) {
        self.apiID = apiID
        self.id = id
        self.title = title
        self.status = status
        self.orderDate = LimuDateFormatting.display(orderDate)
        self.createdAt = LimuDateFormatting.display(createdAt)
        self.orderType = orderType
        self.orderTypeRate = orderTypeRate
        self.currency = LimuCurrency.code(currency)
        self.clientName = clientName
        self.assignedTo = assignedTo
        self.preparedBy = preparedBy
        self.shipmentReference = shipmentReference
        self.totalProductValue = totalProductValue
        self.totalLocalCourier = totalLocalCourier
        self.agencyFee = agencyFee
        self.grandTotal = grandTotal
        self.itemCount = itemCount
        self.approvedItemCount = approvedItemCount
        self.declinedItemCount = declinedItemCount
        self.canClientReview = canClientReview
        self.clientViewURL = clientViewURL
        self.items = items
        self.timeline = timeline
        self.statusUpdates = statusUpdates
    }
}

struct InvoiceItem: Identifiable, Hashable {
    let id: String
    let label: String
    let quantity: Int
    let total: Double
}

struct Payment: Identifiable, Hashable {
    let id: String
    let amount: Double
    let status: String
    let date: String
    let transactionID: String
    let currency: String

    init(
        id: String,
        amount: Double,
        status: String,
        date: String,
        transactionID: String,
        currency: String = LimuCurrency.defaultCode
    ) {
        self.id = id
        self.amount = amount
        self.status = status
        self.date = date
        self.transactionID = transactionID
        self.currency = LimuCurrency.code(currency)
    }
}

struct Invoice: Identifiable, Hashable {
    let apiID: Int
    let id: String
    let status: String
    let date: String
    let total: Double
    let balance: Double
    let discount: Double
    let discountPercentage: Int
    let shipmentID: String
    let cargoID: String
    let currency: String
    let items: [InvoiceItem]
    let payments: [Payment]
    let documentURL: URL?
    /// Set when the invoice was generated from an approved order form.
    let orderFormNumber: String?
    /// "Shipping", "Customs Clearance" or "Order Form"; shown on the invoice so nobody has to guess.
    let typeLabel: String
    let isCustoms: Bool
    /// A link the client can share (for example on WhatsApp) to open the invoice without signing in.
    let shareURL: URL?

    init(
        apiID: Int = 0,
        id: String,
        status: String,
        date: String,
        total: Double,
        balance: Double,
        discount: Double,
        discountPercentage: Int,
        shipmentID: String,
        cargoID: String,
        currency: String = LimuCurrency.defaultCode,
        items: [InvoiceItem],
        payments: [Payment],
        documentURL: URL? = nil,
        orderFormNumber: String? = nil,
        typeLabel: String = "Shipping",
        isCustoms: Bool = false,
        shareURL: URL? = nil
    ) {
        self.apiID = apiID
        self.id = id
        self.status = status
        self.date = LimuDateFormatting.display(date)
        self.total = total
        self.balance = balance
        self.discount = discount
        self.discountPercentage = discountPercentage
        self.shipmentID = shipmentID
        self.cargoID = cargoID
        self.currency = LimuCurrency.code(currency)
        self.items = items
        self.payments = payments
        self.documentURL = documentURL
        self.orderFormNumber = orderFormNumber
        self.typeLabel = typeLabel
        self.isCustoms = isCustoms
        self.shareURL = shareURL
    }
}
struct AppNotification: Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    let category: String
    let timestamp: String
    var isUnread: Bool
    let destination: AppTab
    let objectID: Int?
    /// "cargo", "shipment", "invoice", "order_form" or "kyc_change_request": with `objectID` this is the exact
    /// record the notification is about, so tapping it opens that record rather than a list.
    let objectType: String

    init(id: String, title: String, message: String, category: String, timestamp: String, isUnread: Bool, destination: AppTab, objectID: Int? = nil, objectType: String = "") {
        self.id = id
        self.title = title
        self.message = message
        self.category = category
        self.timestamp = LimuDateFormatting.display(timestamp)
        self.isUnread = isUnread
        self.destination = destination
        self.objectID = objectID
        self.objectType = objectType
    }
}

enum MockData {
    static let cargo: [Cargo] = [
        Cargo(id: "LMU-CGO-0041", status: "In Warehouse", summary: "Electronics & Accessories", packages: 8, weight: 142.5, volume: 0.92, location: "Limu Warehouse, Guangzhou", financeStatus: "Payment Pending", shipmentName: "SEA-GZ-ACC-JUN25", createdAt: "2025-06-02", readyForCollection: false, collectionLocation: nil, notes: "Awaiting payment confirmation before loading."),
        Cargo(id: "LMU-CGO-0038", status: "Ready for Collection", summary: "Clothing & Footwear", packages: 14, weight: 98, volume: 1.24, location: "Limu Warehouse, Accra", financeStatus: "Approved", shipmentName: "SEA-GZ-ACC-MAY25", createdAt: "2025-04-18", readyForCollection: true, collectionLocation: "Limu Accra Depot, Tema Road", notes: nil),
        Cargo(id: "LMU-CGO-0035", status: "In Transit", summary: "Kitchen Appliances", packages: 5, weight: 210, volume: 2.1, location: "At Sea – Atlantic Ocean", financeStatus: "Paid", shipmentName: "SEA-GZ-ACC-MAY25", createdAt: "2025-03-30", readyForCollection: false, collectionLocation: nil, notes: nil),
        Cargo(id: "LMU-CGO-0029", status: "Collected", summary: "Hardware & Tools", packages: 3, weight: 56, volume: 0.38, location: "Collected", financeStatus: "Paid", shipmentName: "SEA-GZ-ACC-MAR25", createdAt: "2025-02-10", readyForCollection: false, collectionLocation: "Limu Accra Depot, Tema Road", notes: nil)
    ]

    static let packages: [CargoPackage] = [
        CargoPackage(id: "PKG-0041-01", content: "Bluetooth Speakers (x6)", quantity: 6, type: "Carton", code: "C-001", courierTracking: "YT2204891023GH", checkedAt: "2025-06-03 11:30", total: 6, checked: 6),
        CargoPackage(id: "PKG-0041-02", content: "Phone Accessories", quantity: 24, type: "Carton", code: "C-002", courierTracking: "YT2204891024GH", checkedAt: "2025-06-03 11:35", total: 24, checked: 24),
        CargoPackage(id: "PKG-0041-03", content: "USB Hubs & Cables", quantity: 50, type: "Bag", code: "B-001", courierTracking: "YT2204891025GH", checkedAt: "2025-06-03 11:42", total: 50, checked: 50)
    ]

    static let cargoTimeline: [TimelineEvent] = [
        TimelineEvent(id: "EV-001", title: "Cargo Created", description: "Cargo registered in system", timestamp: "2025-06-02 09:14", actor: "System"),
        TimelineEvent(id: "EV-002", title: "Packages Verified", description: "All 8 packages counted and confirmed", timestamp: "2025-06-03 11:30", actor: "David K."),
        TimelineEvent(id: "EV-003", title: "Warehouse Check Passed", description: "Cargo passed warehouse inspection", timestamp: "2025-06-04 14:00", actor: "Mary O."),
        TimelineEvent(id: "EV-004", title: "Invoice Generated", description: "Invoice INV-2025-0156 issued", timestamp: "2025-06-04 16:45", actor: "Finance"),
        TimelineEvent(id: "EV-005", title: "Awaiting Payment", description: "Cargo on hold pending payment confirmation", timestamp: "2025-06-05 08:00", actor: "System")
    ]

    static let shipments: [Shipment] = [
        Shipment(id: "SHP-0018", name: "SEA-GZ-ACC-JUN25", status: "Loading", mode: "Sea Freight", departure: "2025-06-20", arrival: "2025-08-05", location: "Guangzhou Port, China", cargoCount: 1, packageCount: 8),
        Shipment(id: "SHP-0015", name: "SEA-GZ-ACC-MAY25", status: "In Transit", mode: "Sea Freight", departure: "2025-05-10", arrival: "2025-06-28", location: "Atlantic Ocean – ETA 18 days", cargoCount: 2, packageCount: 19),
        Shipment(id: "SHP-0012", name: "SEA-GZ-ACC-MAR25", status: "Completed", mode: "Sea Freight", departure: "2025-03-05", arrival: "2025-04-22", location: "Delivered", cargoCount: 1, packageCount: 3)
    ]

    static let shipmentUpdates: [ShipmentUpdate] = [
        ShipmentUpdate(id: "UPD-018-001", shipmentID: "SHP-0018", location: "Guangzhou Port, China", status: "Loading", message: "Container TCKU8821034 assigned and loading has commenced at Guangzhou Port.", timestamp: "2025-06-08 10:00", actor: "Operations"),
        ShipmentUpdate(id: "UPD-018-002", shipmentID: "SHP-0018", location: "Limu Warehouse, Guangzhou", status: "Loading", message: "Cargo consolidation complete. All client cargo packed and sealed.", timestamp: "2025-06-05 15:30", actor: "Warehouse"),
        ShipmentUpdate(id: "UPD-015-001", shipmentID: "SHP-0015", location: "Atlantic Ocean", status: "In Transit", message: "Vessel MV Atlantic Horizon on schedule. No disruptions reported. ETA remains 28 June.", timestamp: "2025-06-09 06:00", actor: "Operations"),
        ShipmentUpdate(id: "UPD-015-002", shipmentID: "SHP-0015", location: "Suez Canal", status: "In Transit", message: "Vessel cleared Suez Canal transit successfully. No delays.", timestamp: "2025-05-28 14:30", actor: "Operations"),
        ShipmentUpdate(id: "UPD-015-003", shipmentID: "SHP-0015", location: "Port Said, Egypt", status: "In Transit", message: "Vessel departed Port Said anchorage. Heading south through Red Sea.", timestamp: "2025-05-27 09:00", actor: "Operations"),
        ShipmentUpdate(id: "UPD-012-001", shipmentID: "SHP-0012", location: "Tema Port, Ghana", status: "Completed", message: "All cargo cleared and available for client collection at Limu Accra Depot.", timestamp: "2025-04-25 09:00", actor: "Operations")
    ]

    static let shipmentPriceList = ShipmentPriceList(
        lastUpdated: "Demo data",
        customsLastUpdated: "Demo data",
        shippingLastUpdated: "Demo data",
        policy: ShipmentPricePolicy(
            weightThresholdPerCbm: 400,
            baseCurrency: "USD",
            counterCurrency: "RMB",
            usdToRmbRate: 7,
            exchangeRateSource: "Demo fallback",
            exchangeRateAsOf: nil,
            exchangeRateError: nil,
            updatedAt: "Demo data"
        ),
        items: [
            ShipmentPriceItem(
                id: "customs-assorted",
                category: "Customs Fees",
                service: "Assorted goods",
                route: "Customs price per CBM",
                rate: 285_000,
                currency: LimuCurrency.defaultCode,
                unit: "CBM",
                updatedAt: "Demo data",
                note: "Configured cargo-content customs fee.",
                icon: "doc.text.fill"
            ),
            ShipmentPriceItem(
                id: "shipping-normal",
                category: "Shipping Fees",
                service: "Normal goods",
                route: "Below 400.00 kg/CBM",
                rate: 120,
                currency: "USD",
                unit: "CBM",
                convertedRate: 840,
                convertedCurrency: "RMB",
                updatedAt: "Demo data",
                note: "Shipping fee per CBM.",
                icon: "shippingbox.fill"
            ),
            ShipmentPriceItem(
                id: "shipping-heavy",
                category: "Shipping Fees",
                service: "Heavy goods",
                route: "At or above 400.00 kg/CBM",
                rate: 160,
                currency: "USD",
                unit: "CBM",
                convertedRate: 1_120,
                convertedCurrency: "RMB",
                updatedAt: "Demo data",
                note: "Heavy-goods shipping fee per CBM.",
                icon: "scalemass.fill"
            ),
            ShipmentPriceItem(
                id: "air-general",
                category: "Air Cargo",
                service: "General goods",
                route: "Air cargo fee per kg",
                rate: 110,
                currency: "RMB",
                unit: "kg",
                updatedAt: nil,
                note: "Portal air-cargo guidance rate.",
                icon: "airplane"
            ),
            ShipmentPriceItem(
                id: "air-electronics",
                category: "Air Cargo",
                service: "Electronics",
                route: "Air cargo fee per kg",
                rate: 180,
                currency: "RMB",
                unit: "kg",
                updatedAt: nil,
                note: "Portal air-cargo guidance rate.",
                icon: "airplane"
            )
        ],
        notes: [
            "This live pricelist is intended for client guidance.",
            "Final invoice values follow measured shipment details and approved service terms.",
            "Converted shipping values use the latest available USD to RMB exchange rate."
        ]
    )

    static let orderForms: [OrderForm] = [
        OrderForm(
            apiID: 48,
            id: "OF-2026-0048",
            title: "Electronics sourcing",
            status: "Client Review",
            orderDate: "2026-06-20",
            createdAt: "2026-06-20 10:20",
            orderType: "Full",
            orderTypeRate: 7,
            clientName: "Limu Client",
            assignedTo: "Sourcing Team",
            preparedBy: "Limu Procurement",
            shipmentReference: "Pending shipment",
            totalProductValue: 1_420_000,
            totalLocalCourier: 85_000,
            agencyFee: 99_400,
            grandTotal: 1_604_400,
            itemCount: 3,
            approvedItemCount: 1,
            declinedItemCount: 0,
            canClientReview: true,
            items: [
                OrderFormItem(apiID: 1, id: "OFI-001", status: "Approved", productName: "Bluetooth speakers", categoryName: "Electronics", description: "Portable wireless speakers with packaging", productLink: URL(string: "https://example.com/speakers"), size: "Carton", quantity: 20, unitPrice: 35_000, productValue: 700_000, localShipping: 42_500, lineTotal: 742_500),
                OrderFormItem(apiID: 2, id: "OFI-002", status: "Draft", productName: "Phone accessories bundle", categoryName: "Electronics", description: "Cases, chargers, USB hubs", size: "Mixed", quantity: 100, unitPrice: 6_200, productValue: 620_000, localShipping: 35_000, lineTotal: 655_000),
                OrderFormItem(apiID: 3, id: "OFI-003", status: "Draft", productName: "Supplier samples", categoryName: "Assorted", description: "Trial SKUs for review", size: "Small parcel", quantity: 1, unitPrice: 100_000, productValue: 100_000, localShipping: 7_500, lineTotal: 107_500)
            ],
            timeline: [
                OrderFormTimelineStep(id: "draft", label: "Draft", reached: true, active: false, note: "Order captured by sourcing team.", changedBy: "Limu Procurement", createdAt: "2026-06-20 10:20"),
                OrderFormTimelineStep(id: "client-review", label: "Client Review", reached: true, active: true, note: "Approve or decline items before purchase.", changedBy: "Client", createdAt: "2026-06-20 12:05"),
                OrderFormTimelineStep(id: "supervisor-review", label: "Supervisor Review", reached: false, active: false, note: "Not started yet", changedBy: "", createdAt: "—"),
                OrderFormTimelineStep(id: "awaiting-payment", label: "Awaiting Payment", reached: false, active: false, note: "Not started yet", changedBy: "", createdAt: "—"),
                OrderFormTimelineStep(id: "pending-purchase", label: "Pending Purchase", reached: false, active: false, note: "Not started yet", changedBy: "", createdAt: "—"),
                OrderFormTimelineStep(id: "purchased", label: "Purchased", reached: false, active: false, note: "Not started yet", changedBy: "", createdAt: "—"),
                OrderFormTimelineStep(id: "dormant", label: "Dormant", reached: false, active: false, note: "Not started yet", changedBy: "", createdAt: "—")
            ],
            statusUpdates: [
                OrderFormStatusUpdate(id: "LOG-001", status: "Client Review", note: "Client started review via item approvals/declines.", changedBy: "Client via mobile app", createdAt: "2026-06-20 12:05"),
                OrderFormStatusUpdate(id: "LOG-002", status: "Item Approved", note: "Client approved Bluetooth speakers", changedBy: "Client via mobile app", createdAt: "2026-06-20 12:07")
            ]
        ),
        OrderForm(
            apiID: 43,
            id: "OF-2026-0043",
            title: "Kitchen appliances",
            status: "Pending Purchase",
            orderDate: "2026-06-10",
            createdAt: "2026-06-10 09:10",
            orderType: "Partial",
            orderTypeRate: 5,
            clientName: "Limu Client",
            assignedTo: "Procurement Desk",
            preparedBy: "Limu Procurement",
            shipmentReference: "SEA-GZ-BLT-JUL26",
            totalProductValue: 2_800_000,
            totalLocalCourier: 125_000,
            agencyFee: 140_000,
            grandTotal: 3_065_000,
            itemCount: 2,
            approvedItemCount: 2,
            declinedItemCount: 0,
            canClientReview: false
        )
    ]

    static let invoices: [Invoice] = [
        Invoice(id: "INV-2025-0156", status: "Not Paid", date: "2025-06-04", total: 2450, balance: 2450, discount: 0, discountPercentage: 0, shipmentID: "SHP-0018", cargoID: "LMU-CGO-0041", currency: LimuCurrency.defaultCode, items: [
            InvoiceItem(id: "ITM-001", label: "Handling Fee", quantity: 1, total: 80),
            InvoiceItem(id: "ITM-002", label: "Storage – 3 days", quantity: 3, total: 45),
            InvoiceItem(id: "ITM-003", label: "Customs Documentation", quantity: 1, total: 120),
            InvoiceItem(id: "ITM-004", label: "Sea Freight (0.92 CBM)", quantity: 1, total: 1885),
            InvoiceItem(id: "ITM-005", label: "Destination Charges", quantity: 1, total: 320)
        ], payments: []),
        Invoice(id: "INV-2025-0144", status: "Partially Paid", date: "2025-05-02", total: 1890, balance: 890, discount: 0, discountPercentage: 0, shipmentID: "SHP-0015", cargoID: "LMU-CGO-0038", currency: LimuCurrency.defaultCode, items: [
            InvoiceItem(id: "ITM-006", label: "Handling Fee", quantity: 1, total: 60),
            InvoiceItem(id: "ITM-007", label: "Sea Freight (1.24 CBM)", quantity: 1, total: 1550),
            InvoiceItem(id: "ITM-008", label: "Destination Charges", quantity: 1, total: 280)
        ], payments: [Payment(id: "PAY-001", amount: 1000, status: "Approved", date: "2025-05-14", transactionID: "TXN-GH-88420")]),
        Invoice(id: "INV-2025-0128", status: "Paid", date: "2025-03-12", total: 980, balance: 0, discount: 50, discountPercentage: 5, shipmentID: "SHP-0012", cargoID: "LMU-CGO-0029", currency: LimuCurrency.defaultCode, items: [
            InvoiceItem(id: "ITM-009", label: "Sea Freight (0.38 CBM)", quantity: 1, total: 750),
            InvoiceItem(id: "ITM-010", label: "Destination Charges", quantity: 1, total: 180),
            InvoiceItem(id: "ITM-011", label: "Loyalty Discount", quantity: 1, total: -50)
        ], payments: [Payment(id: "PAY-002", amount: 980, status: "Approved", date: "2025-03-20", transactionID: "TXN-GH-71203")])
    ]

    static let notifications: [AppNotification] = [
        AppNotification(id: "NOT-001", title: "Cargo Ready for Collection", message: "LMU-CGO-0038 (Clothing & Footwear) is ready for pickup at Limu Accra Depot, Tema Road.", category: "Cargo", timestamp: "2025-06-09 08:30", isUnread: true, destination: .cargo),
        AppNotification(id: "NOT-002", title: "Order form ready for review", message: "OF-2026-0048 has items waiting for your approval before purchase.", category: "Order Form", timestamp: "2026-06-20 12:05", isUnread: true, destination: .orderForms),
        AppNotification(id: "NOT-003", title: "Shipment Update – SEA-GZ-ACC-MAY25", message: "Your shipment has cleared Suez Canal and is on schedule for arrival on 28 June 2025.", category: "Shipment", timestamp: "2025-05-28 14:30", isUnread: false, destination: .shipments),
        AppNotification(id: "NOT-004", title: "Order moved to purchase", message: "OF-2026-0043 is now pending purchase with the sourcing team.", category: "Order Form", timestamp: "2026-06-12 10:00", isUnread: false, destination: .orderForms)
    ]

    static func money(_ value: Double, currency: String? = nil) -> String {
        LimuCurrency.money(value, currency: currency)
    }
}
