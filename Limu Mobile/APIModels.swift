import Foundation

private extension KeyedDecodingContainer {
    func limuString(_ key: Key, default defaultValue: String = "") -> String {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        return defaultValue
    }

    func limuOptionalString(_ key: Key) -> String? {
        let value = limuString(key).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func limuInt(_ key: Key, default defaultValue: Int = 0) -> Int {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? defaultValue
        }
        return defaultValue
    }

    func limuDouble(_ key: Key, default defaultValue: Double = 0) -> Double {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? defaultValue
        }
        return defaultValue
    }

    func limuBool(_ key: Key, default defaultValue: Bool = false) -> Bool {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "y":
                return true
            case "0", "false", "no", "n":
                return false
            default:
                return defaultValue
            }
        }
        return defaultValue
    }

    func limuStringArray(_ key: Key) -> [String] {
        if let values = try? decodeIfPresent([String].self, forKey: key) {
            return values
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}

struct AuthPayloadDTO: Decodable {
    let client: ProfileDTO
    let session: SessionDTO
}

struct RegistrationPayloadDTO: Decodable {
    let verificationRequired: Bool
    let email: String
    let emailSent: Bool
    let expiresAt: String
    let testCode: String?
    let channel: String?
    let phone: String?
    let whatsappSent: Bool?
    let smsSent: Bool?
    let identifier: String?
    let accountLinked: Bool?
}

struct KYCEmailVerificationRequestDTO: Decodable {
    let alreadyVerified: Bool?
    let email: String?
    let expiresAt: String?
    let testCode: String?
}

struct SessionDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: String
    let refreshExpiresAt: String
}

struct ProfileDTO: Codable {
    let id: Int
    let firstName: String
    let lastName: String
    let fullName: String
    let email: String
    let phone: String
    let clientType: String
    let businessName: String
    let businessCategory: String
    let location: String
    let customerCategory: String?
    let shipmentCount: Int
    let lastShipmentDate: String?
    let photoUrl: String?
    let gender: String?
    let dateOfBirth: String?
    let occupations: [String]?
    let interests: [String]?
    let alternatePhones: [String]?
    let kycStatus: String?
}

struct DashboardDTO: Decodable {
    let greetingName: String
    let client: ProfileDTO
    let metrics: DashboardMetricsDTO
    let activeCargo: [CargoDTO]
    let shipments: [ShipmentDTO]
    let orderForms: [OrderFormDTO]?
    let notifications: [NotificationDTO]
}

struct DashboardMetricsDTO: Decodable {
    let activeCargoCount: Int
    let readyForCollectionCount: Int
    let balanceDue: Double
    let currency: String?
    let unreadNotificationCount: Int
    let kycStatus: String
}

struct CargoDTO: Decodable {
    let id: Int
    let trackingNumber: String
    let status: String
    let contentSummary: String
    let packageCount: Int
    let checkedPackageCount: Int
    let weightKg: Double
    let volumeCbm: Double
    let currentLocation: String
    let financeStatus: String
    let shipmentId: Int?
    let shipmentName: String
    let createdAt: String?
    let readyForCollection: Bool
    let collectionLocation: String?
    let notes: String?
    let consignmentValue: Double
    let packages: [CargoPackageDTO]?
    let timeline: [TimelineDTO]?

    var model: Cargo {
        Cargo(
            apiID: id,
            id: trackingNumber.isEmpty ? "CGO-\(id)" : trackingNumber,
            status: status,
            summary: contentSummary,
            packages: packageCount,
            weight: weightKg,
            volume: volumeCbm,
            location: currentLocation,
            financeStatus: financeStatus,
            shipmentName: shipmentName,
            createdAt: createdAt ?? "—",
            readyForCollection: readyForCollection,
            collectionLocation: collectionLocation,
            notes: notes,
            checkedPackages: checkedPackageCount
        )
    }
}

struct CargoPackageDTO: Decodable {
    let id: Int
    let cargoId: Int
    let code: String
    let content: String
    let quantity: Int
    let packageType: String
    let declaredValue: Double
    let courierTrackingNumber: String
    let imageUrl: String?
    let checked: Bool
    let checkedAt: String?
    let createdAt: String?

    var model: CargoPackage {
        CargoPackage(
            id: String(id),
            content: content,
            quantity: quantity,
            type: packageType,
            code: code,
            courierTracking: courierTrackingNumber,
            checkedAt: checkedAt ?? "—",
            total: quantity,
            checked: checked ? quantity : 0
        )
    }
}

struct TimelineDTO: Decodable {
    let id: Int
    let message: String
    let timestamp: String?
    let recordedBy: String

    var model: TimelineEvent {
        TimelineEvent(id: String(id), title: message, description: message, timestamp: timestamp ?? "—", actor: recordedBy)
    }
}

struct ShipmentDTO: Decodable {
    let id: Int
    let name: String
    let status: String
    let mode: String
    let departureDate: String?
    let arrivalDate: String?
    let currentLocation: String
    let clientCargoCount: Int
    let packageCount: Int
    let progress: Double
    let createdAt: String?
    let updates: [ShipmentUpdateDTO]?
    let cargo: [CargoDTO]?

    var model: Shipment {
        Shipment(
            apiID: id,
            id: "SHP-\(id)",
            name: name,
            status: status,
            mode: mode,
            departure: departureDate ?? "—",
            arrival: arrivalDate ?? "—",
            location: currentLocation,
            cargoCount: clientCargoCount,
            packageCount: packageCount,
            progress: progress
        )
    }
}

struct ShipmentUpdateDTO: Decodable {
    let id: Int
    let status: String
    let message: String
    let timestamp: String?
    let recordedBy: String

    func model(shipmentID: String, location: String) -> ShipmentUpdate {
        ShipmentUpdate(id: String(id), shipmentID: shipmentID, location: location, status: status, message: message, timestamp: timestamp ?? "—", actor: recordedBy)
    }
}

struct OrderFormDTO: Decodable {
    let id: Int
    let number: String
    let title: String
    let status: String
    let orderDate: String?
    let createdAt: String?
    let orderType: String
    let orderTypeLabel: String?
    let orderTypeRate: Double
    let currency: String?
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
    let clientViewUrl: String?
    let items: [OrderFormItemDTO]?
    let timeline: [OrderFormTimelineStepDTO]?
    let statusUpdates: [OrderFormStatusUpdateDTO]?

    enum CodingKeys: String, CodingKey {
        case id, number, title, status, orderDate, createdAt, orderType, orderTypeLabel, orderTypeRate, currency
        case clientName, assignedTo, preparedBy, shipmentReference, totalProductValue, totalLocalCourier, agencyFee
        case grandTotal, itemCount, approvedItemCount, declinedItemCount, canClientReview, clientViewUrl
        case items, timeline, statusUpdates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.limuInt(.id)
        number = container.limuString(.number, default: "OF-\(id)")
        title = container.limuString(.title)
        status = container.limuString(.status, default: "Draft")
        orderDate = container.limuOptionalString(.orderDate)
        createdAt = container.limuOptionalString(.createdAt)
        let decodedOrderType = container.limuString(.orderType, default: "full")
        orderType = decodedOrderType
        orderTypeLabel = container.limuOptionalString(.orderTypeLabel)
        orderTypeRate = container.limuDouble(.orderTypeRate, default: decodedOrderType == "partial" ? 5 : 7)
        currency = container.limuOptionalString(.currency)
        clientName = container.limuString(.clientName)
        assignedTo = container.limuString(.assignedTo)
        preparedBy = container.limuString(.preparedBy)
        shipmentReference = container.limuString(.shipmentReference)
        totalProductValue = container.limuDouble(.totalProductValue)
        totalLocalCourier = container.limuDouble(.totalLocalCourier)
        agencyFee = container.limuDouble(.agencyFee)
        grandTotal = container.limuDouble(.grandTotal)
        itemCount = container.limuInt(.itemCount)
        approvedItemCount = container.limuInt(.approvedItemCount)
        declinedItemCount = container.limuInt(.declinedItemCount)
        let lowerStatus = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        canClientReview = container.limuBool(.canClientReview, default: ["draft", "client review"].contains(lowerStatus))
        clientViewUrl = container.limuOptionalString(.clientViewUrl)
        items = try? container.decodeIfPresent([OrderFormItemDTO].self, forKey: .items)
        timeline = try? container.decodeIfPresent([OrderFormTimelineStepDTO].self, forKey: .timeline)
        statusUpdates = try? container.decodeIfPresent([OrderFormStatusUpdateDTO].self, forKey: .statusUpdates)
    }

    var model: OrderForm {
        OrderForm(
            apiID: id,
            id: number.isEmpty ? "OF-\(id)" : number,
            title: title,
            status: status,
            orderDate: orderDate ?? createdAt ?? "—",
            createdAt: createdAt ?? "—",
            orderType: orderTypeLabel ?? orderType.capitalized,
            orderTypeRate: orderTypeRate,
            currency: LimuCurrency.code(currency),
            clientName: clientName,
            assignedTo: assignedTo,
            preparedBy: preparedBy,
            shipmentReference: shipmentReference,
            totalProductValue: totalProductValue,
            totalLocalCourier: totalLocalCourier,
            agencyFee: agencyFee,
            grandTotal: grandTotal,
            itemCount: itemCount,
            approvedItemCount: approvedItemCount,
            declinedItemCount: declinedItemCount,
            canClientReview: canClientReview,
            clientViewURL: clientViewUrl.flatMap(URL.init(string:)),
            items: (items ?? []).map(\.model),
            timeline: (timeline ?? []).map(\.model),
            statusUpdates: (statusUpdates ?? []).map(\.model)
        )
    }
}

struct OrderFormListDTO: Decodable {
    let items: [OrderFormDTO]

    private enum CodingKeys: String, CodingKey {
        case items
        case orderForms
    }

    init(from decoder: Decoder) throws {
        if let items = try? [OrderFormDTO](from: decoder) {
            self.items = items
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decodeIfPresent([OrderFormDTO].self, forKey: .items)) ?? (try? container.decodeIfPresent([OrderFormDTO].self, forKey: .orderForms)) ?? []
    }
}

struct OrderFormItemDTO: Decodable {
    let id: Int
    let status: String
    let productName: String
    let categoryName: String
    let description: String
    let productLink: String?
    let size: String
    let quantity: Int
    let unitPrice: Double
    let productValue: Double
    let localShipping: Double
    let lineTotal: Double
    let trackingNumber: String
    let photoUrls: [String]
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, productName, categoryName, description, productLink, size, quantity, unitPrice
        case productValue, localShipping, lineTotal, trackingNumber, photoUrls, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.limuInt(.id)
        status = container.limuString(.status, default: "Draft")
        productName = container.limuString(.productName)
        categoryName = container.limuString(.categoryName)
        description = container.limuString(.description)
        productLink = container.limuOptionalString(.productLink)
        size = container.limuString(.size)
        quantity = container.limuInt(.quantity)
        unitPrice = container.limuDouble(.unitPrice)
        productValue = container.limuDouble(.productValue)
        localShipping = container.limuDouble(.localShipping)
        lineTotal = container.limuDouble(.lineTotal, default: productValue + localShipping)
        trackingNumber = container.limuString(.trackingNumber)
        photoUrls = container.limuStringArray(.photoUrls)
        createdAt = container.limuOptionalString(.createdAt)
    }

    var model: OrderFormItem {
        OrderFormItem(
            apiID: id,
            id: "OFI-\(id)",
            status: status,
            productName: productName,
            categoryName: categoryName,
            description: description,
            productLink: productLink.flatMap(URL.init(string:)),
            size: size,
            quantity: quantity,
            unitPrice: unitPrice,
            productValue: productValue,
            localShipping: localShipping,
            lineTotal: lineTotal,
            trackingNumber: trackingNumber,
            photoURLs: photoUrls.compactMap(URL.init(string:)),
            createdAt: createdAt ?? "—"
        )
    }
}

struct OrderFormStatusUpdateDTO: Decodable {
    let id: String
    let status: String
    let note: String
    let changedBy: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, note, changedBy, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.limuString(.id)
        status = container.limuString(.status, default: "Update")
        note = container.limuString(.note)
        changedBy = container.limuString(.changedBy)
        createdAt = container.limuOptionalString(.createdAt)
    }

    var model: OrderFormStatusUpdate {
        OrderFormStatusUpdate(id: id, status: status, note: note, changedBy: changedBy, createdAt: createdAt ?? "—")
    }
}

struct OrderFormTimelineStepDTO: Decodable {
    let id: String
    let label: String
    let reached: Bool
    let active: Bool
    let note: String
    let changedBy: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, label, reached, active, note, changedBy, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.limuString(.id)
        label = container.limuString(.label)
        reached = container.limuBool(.reached)
        active = container.limuBool(.active)
        note = container.limuString(.note)
        changedBy = container.limuString(.changedBy)
        createdAt = container.limuOptionalString(.createdAt)
    }

    var model: OrderFormTimelineStep {
        OrderFormTimelineStep(id: id, label: label, reached: reached, active: active, note: note, changedBy: changedBy, createdAt: createdAt ?? "—")
    }
}

struct OrderFormActionResultDTO: Decodable {
    let order: OrderFormDTO
    let supervisorNotified: Bool?
}

struct NotificationDTO: Decodable {
    let id: String
    let title: String
    let message: String
    let category: String
    let timestamp: String
    let isRead: Bool
    let destination: String
    let objectType: String
    let objectId: Int?

    var model: AppNotification {
        let normalized = destination
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let tab: AppTab
        switch normalized {
        case "cargo":
            tab = .cargo
        case "shipment", "shipments":
            tab = .shipments
        case "order", "order form", "order forms", "orderform", "orderforms", "invoice", "invoices", "payment":
            tab = .orderForms
        case "profile", "kyc":
            tab = .profile
        default:
            tab = .home
        }
        return AppNotification(id: id, title: title, message: message, category: category, timestamp: timestamp, isUnread: !isRead, destination: tab, objectID: objectId)
    }
}

struct KYCRecordDTO: Decodable {
    let status: String
    let submittedAt: String?
    let submission: KYCSubmissionDTO?
}

struct CategoryDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct ShipmentPriceListDTO: Decodable {
    let lastUpdated: String?
    let customsLastUpdated: String?
    let shippingLastUpdated: String?
    let customs: [CustomsPriceRowDTO]?
    let shipping: ShippingPriceListSectionDTO?
    let airCargo: [AirCargoPriceRowDTO]?
    let notes: [String]?

    var model: ShipmentPriceList {
        let policy = shipping?.policy?.model ?? ShipmentPricePolicy(
            weightThresholdPerCbm: 400,
            baseCurrency: "USD",
            counterCurrency: "RMB",
            usdToRmbRate: 7,
            exchangeRateSource: "Saved portal rate",
            exchangeRateAsOf: nil,
            exchangeRateError: nil,
            updatedAt: nil
        )
        let customsItems = (customs ?? []).map(\.model)
        let shippingItems = (shipping?.tiers ?? []).map(\.model)
        let airItems = (airCargo ?? []).map(\.model)

        return ShipmentPriceList(
            lastUpdated: lastUpdated,
            customsLastUpdated: customsLastUpdated,
            shippingLastUpdated: shippingLastUpdated,
            policy: policy,
            items: customsItems + shippingItems + airItems,
            notes: notes ?? []
        )
    }
}

struct CustomsPriceRowDTO: Decodable {
    let id: String
    let category: String
    let pricePerCbm: Double
    let currency: String
    let updatedAt: String?

    var model: ShipmentPriceItem {
        ShipmentPriceItem(
            id: id,
            category: "Customs Fees",
            service: category,
            route: "Customs price per CBM",
            rate: pricePerCbm,
            currency: LimuCurrency.code(currency),
            unit: "CBM",
            updatedAt: updatedAt,
            note: "Configured cargo-content customs fee.",
            icon: "doc.text.fill"
        )
    }
}

struct ShippingPriceListSectionDTO: Decodable {
    let policy: ShippingPricePolicyDTO?
    let tiers: [ShippingPriceTierDTO]?
}

struct ShippingPricePolicyDTO: Decodable {
    let weightThresholdPerCbm: Double
    let baseCurrency: String
    let counterCurrency: String
    let usdToRmbRate: Double
    let exchangeRateSource: String
    let exchangeRateAsOf: String?
    let exchangeRateError: String?
    let updatedAt: String?

    var model: ShipmentPricePolicy {
        ShipmentPricePolicy(
            weightThresholdPerCbm: weightThresholdPerCbm,
            baseCurrency: LimuCurrency.code(baseCurrency),
            counterCurrency: LimuCurrency.code(counterCurrency),
            usdToRmbRate: usdToRmbRate,
            exchangeRateSource: exchangeRateSource,
            exchangeRateAsOf: exchangeRateAsOf,
            exchangeRateError: exchangeRateError,
            updatedAt: updatedAt
        )
    }
}

struct ShippingPriceTierDTO: Decodable {
    let id: String
    let code: String
    let label: String
    let policy: String
    let pricePerCbm: Double?
    let currency: String
    let convertedPricePerCbm: Double?
    let convertedCurrency: String
    let updatedAt: String?
    let updatedBy: String?

    var model: ShipmentPriceItem {
        ShipmentPriceItem(
            id: id,
            category: "Shipping Fees",
            service: label,
            route: policy,
            rate: pricePerCbm,
            currency: LimuCurrency.code(currency),
            unit: "CBM",
            convertedRate: convertedPricePerCbm,
            convertedCurrency: LimuCurrency.code(convertedCurrency),
            updatedAt: updatedAt,
            note: note,
            icon: icon
        )
    }

    private var icon: String {
        switch code {
        case "heavy": "scalemass.fill"
        case "dangerous": "exclamationmark.triangle.fill"
        default: "shippingbox.fill"
        }
    }

    private var note: String {
        if let updatedBy, !updatedBy.isEmpty {
            return "Shipping fee per CBM. Updated by \(updatedBy)."
        }
        return "Shipping fee per CBM."
    }
}

struct AirCargoPriceRowDTO: Decodable {
    let id: String
    let label: String
    let ratePerKg: Double
    let currency: String
    let updatedAt: String?

    var model: ShipmentPriceItem {
        ShipmentPriceItem(
            id: id,
            category: "Air Cargo",
            service: label,
            route: "Air cargo fee per kg",
            rate: ratePerKg,
            currency: LimuCurrency.code(currency),
            unit: "kg",
            updatedAt: updatedAt,
            note: "Portal air-cargo guidance rate.",
            icon: "airplane"
        )
    }
}

struct KYCSubmissionDTO: Codable {
    let id: Int?
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let gender: String
    let clientType: String
    let businessName: String
    let businessCategory: String
    let businessSize: String
    let businessOffering: String
    let tradeIntent: String?
    let goodsCategories: [String]
    let serviceCategories: [String]
    let occupations: [String]
    let interests: [String]
    let location: String
    let dateOfBirth: String?
    let notes: String
    let termsAccepted: Bool
    let updatedAt: String?
}

struct APIEmpty: Decodable {}
struct UpdatedCountDTO: Decodable { let updated: Int }
