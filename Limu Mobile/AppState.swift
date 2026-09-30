import Foundation
import Combine
import UIKit
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isCheckingSession = true
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var lastErrorCode: String?
    @Published var profile: ProfileDTO?
    @Published var dashboard: DashboardDTO?
    @Published var cargo: [Cargo] = []
    @Published var shipments: [Shipment] = []
    @Published var invoices: [Invoice] = []
    @Published var orderForms: [OrderForm] = []
    @Published var notifications: [AppNotification] = []
    @Published private var demoKYCCompleted = false

    private let api = APIClient.shared
    private let demoMode: Bool
    private static let storedPushTokenKey = "limuAPNsToken"
    /// Typed back by the user, and echoed to the API, before an account is deleted.
    /// `nonisolated` so the delete screen can compare against it outside the actor,
    /// matching how `KeychainStore.service` is declared in `APIClient.swift`.
    nonisolated static let accountDeletionConfirmation = "DELETE"

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        demoMode = arguments.contains("--logged-in")
        if demoMode {
            demoKYCCompleted = arguments.contains("--kyc-complete")
            isAuthenticated = true
            isCheckingSession = false
            cargo = MockData.cargo
            shipments = MockData.shipments
            invoices = MockData.invoices
            orderForms = MockData.orderForms
            let demoNotifications = MockData.notifications
            notifications = demoKYCCompleted
                ? demoNotifications
                : demoNotifications.filter { !$0.destination.requiresCompletedKYC }
        }
    }

    var unreadCount: Int { notifications.filter(\.isUnread).count }

    var kycStatus: String {
        dashboard?.metrics.kycStatus
            ?? profile?.kycStatus
            ?? (demoMode && demoKYCCompleted ? "Completed" : "Incomplete")
    }

    var hasCompletedKYC: Bool {
        Self.hasCompletedKYC(status: kycStatus)
    }

    var clientType: String {
        if let value = profile?.clientType, !value.isEmpty { return value }
        return ProcessInfo.processInfo.arguments.contains("--personal-account") ? "Personal" : "Business"
    }

    func bootstrap() async {
        guard !demoMode else { return }
        guard APIClient.hasStoredSession else {
            isCheckingSession = false
            return
        }
        do {
            try await refreshAll()
            isAuthenticated = true
            await registerStoredPushTokenIfAvailable()
            configurePushNotifications()
        } catch {
            api.clearSession()
            isAuthenticated = false
        }
        isCheckingSession = false
    }

    func login(identifier: String, password: String, stayLoggedIn: Bool) async -> Bool {
        return await runBusy {
            let payload: AuthPayloadDTO = try await api.post(
                "auth/login.php",
                body: ["identifier": identifier, "password": password, "deviceId": deviceID],
                authenticated: false
            )
            api.store(payload.session, persist: stayLoggedIn)
            profile = payload.client
            do { try await refreshAll() }
            catch { api.clearSession(); throw error }
            isAuthenticated = true
            await registerStoredPushTokenIfAvailable()
            configurePushNotifications()
        }
    }

    func register(firstName: String, lastName: String, email: String, phone: String, password: String, clientType: String, businessName: String, location: String) async -> RegistrationPayloadDTO? {
        var registration: RegistrationPayloadDTO?
        let success = await runBusy {
            var body: [String: Any] = [
                "firstName": firstName, "lastName": lastName, "email": email,
                "phone": phone, "password": password, "clientType": clientType,
                "location": location, "deviceId": deviceID
            ]
            if !businessName.isEmpty { body["businessName"] = businessName }
            registration = try await api.post("auth/register.php", body: body, authenticated: false)
        }
        return success ? registration : nil
    }

    func verifyRegistrationEmail(identifier: String, code: String) async -> Bool {
        await runBusy {
            let payload: AuthPayloadDTO = try await api.post(
                "auth/verify-email.php",
                body: ["identifier": identifier, "code": code, "deviceId": deviceID],
                authenticated: false
            )
            api.store(payload.session, persist: true)
            profile = payload.client
            do { try await refreshAll() }
            catch { api.clearSession(); throw error }
            isAuthenticated = true
            await registerStoredPushTokenIfAvailable()
            configurePushNotifications()
        }
    }

    /// Phone codes (WhatsApp or SMS at the backend's choice) are checked by verify-phone.php and sign the client straight in.
    func verifyRegistrationPhone(identifier: String, code: String) async -> Bool {
        await runBusy {
            let payload: AuthPayloadDTO = try await api.post(
                "auth/verify-phone.php",
                body: ["identifier": identifier, "code": code, "deviceId": deviceID],
                authenticated: false
            )
            api.store(payload.session, persist: true)
            profile = payload.client
            do { try await refreshAll() }
            catch { api.clearSession(); throw error }
            isAuthenticated = true
            await registerStoredPushTokenIfAvailable()
            configurePushNotifications()
        }
    }

    /// Resends the registration code on a specific channel ("sms" for the phone, or "email").
    func resendRegistrationVerification(identifier: String, channel: String) async -> Bool {
        await runBusy {
            try await api.send(
                "auth/resend-verification.php",
                body: ["identifier": identifier, "channel": channel, "deviceId": deviceID],
                authenticated: false
            )
        }
    }

    func clearError() {
        errorMessage = nil
        lastErrorCode = nil
    }

    func requestPasswordReset(identifier: String) async -> Bool {
        await runBusy {
            try await api.send("auth/forgot-password.php", body: ["identifier": identifier], authenticated: false)
        }
    }

    func completePasswordReset(identifier: String, code: String, password: String) async -> Bool {
        await runBusy {
            try await api.send(
                "auth/reset-password.php",
                body: ["identifier": identifier, "code": code, "password": password],
                authenticated: false
            )
        }
    }

    func requestAccountClaim(identifier: String) async -> Bool {
        await runBusy {
            try await api.send("auth/claim/request.php", body: ["identifier": identifier], authenticated: false)
        }
    }

    func completeAccountClaim(token: String, password: String) async -> Bool {
        await runBusy {
            try await api.send("auth/claim/complete.php", body: ["token": token, "password": password], authenticated: false)
        }
    }

    func logout() async {
        // Guarded on isAuthenticated so this stays a no-op when the session has
        // already gone — deleteAccount() clears it before the view unwinds.
        if !demoMode, isAuthenticated {
            await revokeStoredPushToken()
            try? await api.send("auth/logout.php", body: ["allSessions": false])
        }
        clearLocalState()
    }

    /// Permanently deletes the signed-in client's account.
    ///
    /// Required by App Store Review Guideline 5.1.1(v): an app that lets people
    /// create an account has to let them start deleting it from inside the app.
    /// The password is re-checked server side so a borrowed unlocked phone
    /// cannot wipe someone's account.
    func deleteAccount(password: String) async -> Bool {
        guard !demoMode else {
            clearLocalState()
            return true
        }

        // Drop the device off the push register first, while the session is
        // still valid enough to authenticate the call.
        await revokeStoredPushToken()

        let deleted = await runBusy {
            try await api.send(
                "profile/delete.php",
                method: "DELETE",
                body: ["password": password, "confirm": Self.accountDeletionConfirmation]
            )
        }

        guard deleted else {
            // Still signed in, so put the device back on the push register
            // rather than leaving it silently unreachable.
            await registerStoredPushTokenIfAvailable()
            return false
        }

        UserDefaults.standard.removeObject(forKey: Self.storedPushTokenKey)
        clearLocalState()
        return true
    }

    private func clearLocalState() {
        api.clearSession()
        isAuthenticated = false
        profile = nil
        dashboard = nil
        cargo = []
        shipments = []
        invoices = []
        orderForms = []
        notifications = []
    }

    private func emptyIfKYCRequired<Value>(_ load: () async throws -> [Value]) async throws -> [Value] {
        do {
            return try await load()
        } catch let error as APIError where error.code == "KYC_REQUIRED" {
            return []
        }
    }

    func refreshAll() async throws {
        let dashboardDTO: DashboardDTO = try await api.get("dashboard.php")
        // Until KYC is complete the backend answers these list endpoints with 403 KYC_REQUIRED;
        // that means "no data yet", not a failed login, so the dashboards render empty.
        let cargoDTOs: [CargoDTO] = try await emptyIfKYCRequired {
            try await api.get("cargo/index.php", query: [URLQueryItem(name: "perPage", value: "100")])
        }
        let shipmentDTOs: [ShipmentDTO] = try await emptyIfKYCRequired {
            try await api.get("shipments/index.php", query: [URLQueryItem(name: "perPage", value: "100")])
        }
        let orderFormDTOs: [OrderFormDTO]
        do {
            orderFormDTOs = try await api.get("orderforms/index.php", query: [URLQueryItem(name: "perPage", value: "100")])
        } catch {
            orderFormDTOs = dashboardDTO.orderForms ?? []
        }
        let notificationDTOs: [NotificationDTO] = try await api.get("notifications/index.php", query: [URLQueryItem(name: "limit", value: "100")])
        dashboard = dashboardDTO
        profile = dashboardDTO.client
        cargo = cargoDTOs.map(\.model)
        shipments = shipmentDTOs.map(\.model)
        invoices = []
        orderForms = orderFormDTOs.map(\.model)
        notifications = notificationDTOs.map(\.model)
        await hydrateOrderFormsFromNotifications()
    }

    // MARK: - Per-screen refresh
    // Each screen pulls its own latest data when it appears so newly created
    // records show up without a logout/login cycle. Failures are intentionally
    // silent: a transient network blip just leaves the last-known data on screen.

    private var liveSession: Bool { !demoMode && isAuthenticated }

    func refreshCargo() async {
        guard liveSession else { return }
        if let cargoDTOs: [CargoDTO] = try? await api.get("cargo/index.php", query: [URLQueryItem(name: "perPage", value: "100")]) {
            cargo = cargoDTOs.map(\.model)
        }
    }

    func refreshShipments() async {
        guard liveSession else { return }
        if let shipmentDTOs: [ShipmentDTO] = try? await api.get("shipments/index.php", query: [URLQueryItem(name: "perPage", value: "100")]) {
            shipments = shipmentDTOs.map(\.model)
        }
    }

    func refreshOrderForms() async {
        guard liveSession else { return }
        if let orderFormDTOs: [OrderFormDTO] = try? await api.get("orderforms/index.php", query: [URLQueryItem(name: "perPage", value: "100")]) {
            orderForms = orderFormDTOs.map(\.model)
        }
        await hydrateOrderFormsFromNotifications()
    }

    func refreshNotifications() async {
        guard liveSession else { return }
        if let notificationDTOs: [NotificationDTO] = try? await api.get("notifications/index.php", query: [URLQueryItem(name: "limit", value: "100")]) {
            notifications = notificationDTOs.map(\.model)
        }
    }

    func refreshDashboard() async {
        guard liveSession else { return }
        if let dashboardDTO: DashboardDTO = try? await api.get("dashboard.php") {
            dashboard = dashboardDTO
            profile = dashboardDTO.client
        }
    }

    func refreshHome() async {
        guard liveSession else { return }
        await refreshDashboard()
        await refreshCargo()
        await refreshShipments()
        await refreshOrderForms()
        await refreshNotifications()
    }

    func fetchCargoDetail(_ id: Int) async throws -> (Cargo, [CargoPackage], [TimelineEvent]) {
        if demoMode, let cargo = cargo.first(where: { $0.apiID == id || id == 0 }) {
            return (cargo, MockData.packages, MockData.cargoTimeline)
        }
        let dto: CargoDTO = try await api.get("cargo/show.php", query: [URLQueryItem(name: "id", value: String(id))])
        return (dto.model, (dto.packages ?? []).map(\.model), (dto.timeline ?? []).map(\.model))
    }

    func fetchShipmentDetail(_ id: Int) async throws -> (Shipment, [ShipmentUpdate], [Cargo]) {
        if demoMode, let shipment = shipments.first(where: { $0.apiID == id || id == 0 }) {
            return (shipment, MockData.shipmentUpdates.filter { $0.shipmentID == shipment.id }, cargo)
        }
        let dto: ShipmentDTO = try await api.get("shipments/show.php", query: [URLQueryItem(name: "id", value: String(id))])
        let shipment = dto.model
        return (shipment, (dto.updates ?? []).map { $0.model(shipmentID: shipment.id, location: shipment.location) }, (dto.cargo ?? []).map(\.model))
    }

    func fetchInvoiceDetail(_ id: Int) async throws -> Invoice {
        if demoMode { return invoices.first(where: { $0.apiID == id || id == 0 }) ?? MockData.invoices[0] }
        let dto: InvoiceDTO = try await api.get("invoices/show.php", query: [URLQueryItem(name: "id", value: String(id))])
        return dto.model
    }

    func fetchOrderFormDetail(_ id: Int) async throws -> OrderForm {
        if demoMode {
            return orderForms.first(where: { $0.apiID == id || $0.id == "OF-\(id)" || id == 0 }) ?? MockData.orderForms[0]
        }
        let dto: OrderFormDTO = try await api.get("orderforms/show.php", query: [URLQueryItem(name: "id", value: String(id))])
        let orderForm = dto.model
        upsertOrderForm(orderForm)
        return orderForm
    }

    func setOrderFormItemStatus(orderFormID: Int, itemID: Int, action: String) async -> OrderForm? {
        if demoMode {
            guard let index = orderForms.firstIndex(where: { $0.apiID == orderFormID || orderFormID == 0 }) else { return orderForms.first }
            let current = orderForms[index]
            let newStatus = action == "decline" ? "Declined" : "Approved"
            let updatedItems = current.items.map { item in
                item.apiID == itemID || item.id == "OFI-\(itemID)"
                    ? OrderFormItem(
                        apiID: item.apiID,
                        id: item.id,
                        status: newStatus,
                        productName: item.productName,
                        categoryName: item.categoryName,
                        description: item.description,
                        productLink: item.productLink,
                        size: item.size,
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        productValue: item.productValue,
                        localShipping: item.localShipping,
                        lineTotal: item.lineTotal,
                        trackingNumber: item.trackingNumber,
                        photoURLs: item.photoURLs,
                        createdAt: item.createdAt
                    )
                    : item
            }
            let updated = OrderForm(
                apiID: current.apiID,
                id: current.id,
                title: current.title,
                status: current.status == "Draft" ? "Client Review" : current.status,
                orderDate: current.orderDate,
                createdAt: current.createdAt,
                orderType: current.orderType,
                orderTypeRate: current.orderTypeRate,
                currency: current.currency,
                clientName: current.clientName,
                assignedTo: current.assignedTo,
                preparedBy: current.preparedBy,
                shipmentReference: current.shipmentReference,
                totalProductValue: current.totalProductValue,
                totalLocalCourier: current.totalLocalCourier,
                agencyFee: current.agencyFee,
                grandTotal: current.grandTotal,
                itemCount: current.itemCount,
                approvedItemCount: updatedItems.filter { $0.status == "Approved" }.count,
                declinedItemCount: updatedItems.filter { $0.status == "Declined" }.count,
                canClientReview: current.canClientReview,
                clientViewURL: current.clientViewURL,
                items: updatedItems,
                timeline: current.timeline,
                statusUpdates: current.statusUpdates
            )
            orderForms[index] = updated
            return updated
        }

        var updatedOrder: OrderForm?
        let success = await runBusy {
            let result: OrderFormActionResultDTO = try await api.post(
                "orderforms/item-action.php",
                body: ["id": orderFormID, "itemId": itemID, "action": action]
            )
            updatedOrder = result.order.model
            if let updatedOrder { upsertOrderForm(updatedOrder) }
        }
        return success ? updatedOrder : nil
    }

    func completeOrderFormReview(orderFormID: Int) async -> OrderForm? {
        if demoMode {
            guard let index = orderForms.firstIndex(where: { $0.apiID == orderFormID || orderFormID == 0 }) else { return orderForms.first }
            let current = orderForms[index]
            let updated = OrderForm(
                apiID: current.apiID,
                id: current.id,
                title: current.title,
                status: "Supervisor Review",
                orderDate: current.orderDate,
                createdAt: current.createdAt,
                orderType: current.orderType,
                orderTypeRate: current.orderTypeRate,
                currency: current.currency,
                clientName: current.clientName,
                assignedTo: current.assignedTo,
                preparedBy: current.preparedBy,
                shipmentReference: current.shipmentReference,
                totalProductValue: current.totalProductValue,
                totalLocalCourier: current.totalLocalCourier,
                agencyFee: current.agencyFee,
                grandTotal: current.grandTotal,
                itemCount: current.itemCount,
                approvedItemCount: current.approvedItemCount,
                declinedItemCount: current.declinedItemCount,
                canClientReview: false,
                clientViewURL: current.clientViewURL,
                items: current.items,
                timeline: current.timeline,
                statusUpdates: current.statusUpdates
            )
            orderForms[index] = updated
            return updated
        }

        var updatedOrder: OrderForm?
        let success = await runBusy {
            let result: OrderFormActionResultDTO = try await api.post(
                "orderforms/review-complete.php",
                body: ["id": orderFormID]
            )
            updatedOrder = result.order.model
            if let updatedOrder { upsertOrderForm(updatedOrder) }
        }
        return success ? updatedOrder : nil
    }

    func markRead(_ notification: AppNotification) async {
        guard notification.isUnread else { return }
        if !demoMode { try? await api.send("notifications/read.php", method: "PATCH", body: ["id": notification.id]) }
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) { notifications[index].isUnread = false }
    }

    func markAllRead() async {
        if !demoMode { try? await api.send("notifications/read-all.php") }
        for index in notifications.indices { notifications[index].isUnread = false }
    }

    func configurePushNotifications() {
        guard !demoMode else { return }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            do {
                let settings = await center.notificationSettings()
                let authorized: Bool
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    authorized = true
                case .notDetermined:
                    authorized = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                case .denied:
                    authorized = false
                @unknown default:
                    authorized = false
                }

                if authorized {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                // Push registration should not block sign-in or data refresh.
            }
        }
    }

    func savePushToken(_ token: String) async {
        guard !demoMode else { return }
        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        UserDefaults.standard.set(cleaned, forKey: Self.storedPushTokenKey)
        guard isAuthenticated else { return }
        try? await api.send(
            "devices/push-token.php",
            body: [
                "token": cleaned,
                "platform": "ios",
                "environment": Self.apnsEnvironment,
                "deviceId": deviceID
            ]
        )
    }

    func refreshAfterRemoteNotification() async {
        guard isAuthenticated, !demoMode else { return }
        try? await refreshAll()
    }

    func updateProfile(_ values: [String: Any]) async -> Bool {
        await runBusy {
            let updated: ProfileDTO = try await api.patch("profile/index.php", body: values)
            profile = updated
            dashboard = nil
        }
    }

    func changePassword(current: String, new: String) async -> Bool {
        let success = await runBusy {
            try await api.send("profile/password.php", method: "PATCH", body: ["currentPassword": current, "newPassword": new])
        }
        if success {
            api.clearSession()
            isAuthenticated = false
        }
        return success
    }

    func loadKYC() async throws -> KYCRecordDTO { try await api.get("kyc/index.php") }

    func loadCategories(query: String = "") async throws -> [CategoryDTO] {
        if demoMode {
            let categories = [
                CategoryDTO(id: 3, name: "Assorted"),
                CategoryDTO(id: 2, name: "Electronics"),
                CategoryDTO(id: 1, name: "Spare parts")
            ]
            let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
            return search.isEmpty ? categories : categories.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        return try await api.get(
            "categories/get.php",
            query: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "500")
            ]
        )
    }

    func saveKYC(_ values: [String: Any], submit: Bool) async -> Bool {
        if demoMode {
            if submit { demoKYCCompleted = true }
            return true
        }
        return await runBusy {
            let _: KYCRecordDTO
            if submit {
                let value: KYCRecordDTO = try await api.post("kyc/submit.php", body: values)
                _ = value
                try await refreshAll()
            } else {
                let value: KYCRecordDTO = try await api.put("kyc/index.php", body: values)
                _ = value
            }
        }
    }

    private static func hasCompletedKYC(status: String) -> Bool {
        status.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Completed") == .orderedSame
    }

    private func upsertOrderForm(_ orderForm: OrderForm) {
        if let index = orderForms.firstIndex(where: { $0.apiID == orderForm.apiID || $0.id == orderForm.id }) {
            orderForms[index] = orderForm
        } else {
            orderForms.insert(orderForm, at: 0)
        }
    }

    private func hydrateOrderFormsFromNotifications() async {
        guard liveSession else { return }
        let knownIDs = Set(orderForms.map(\.apiID))
        let referencedIDs = notifications.compactMap { notification -> Int? in
            guard let objectID = notification.objectID, !knownIDs.contains(objectID) else { return nil }
            let category = notification.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return category == "order form" || notification.destination == .orderForms ? objectID : nil
        }
        for id in Array(Set(referencedIDs)).prefix(5) {
            if let dto: OrderFormDTO = try? await api.get("orderforms/show.php", query: [URLQueryItem(name: "id", value: String(id))]) {
                upsertOrderForm(dto.model)
            }
        }
    }

    func uploadPayment(invoiceID: Int, amount: Double, transactionID: String, notes: String, fileURL: URL) async -> Bool {
        await runBusy {
            let _: PaymentDTO = try await api.uploadPaymentProof(invoiceID: invoiceID, amount: amount, transactionID: transactionID, notes: notes, fileURL: fileURL)
            try await refreshAll()
        }
    }

    private func runBusy(_ operation: () async throws -> Void) async -> Bool {
        isBusy = true
        errorMessage = nil
        lastErrorCode = nil
        defer { isBusy = false }
        do {
            try await operation()
            return true
        } catch {
            lastErrorCode = (error as? APIError)?.code
            errorMessage = error.localizedDescription
            return false
        }
    }

    private var deviceID: String {
        if let value = UserDefaults.standard.string(forKey: "limuDeviceID") { return value }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: "limuDeviceID")
        return value
    }

    private func registerStoredPushTokenIfAvailable() async {
        guard let token = UserDefaults.standard.string(forKey: Self.storedPushTokenKey), !token.isEmpty else { return }
        await savePushToken(token)
    }

    private func revokeStoredPushToken() async {
        guard let token = UserDefaults.standard.string(forKey: Self.storedPushTokenKey), !token.isEmpty else {
            try? await api.send("devices/push-token.php", method: "DELETE", body: ["deviceId": deviceID])
            return
        }
        try? await api.send(
            "devices/push-token.php",
            method: "DELETE",
            body: ["token": token, "deviceId": deviceID]
        )
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }
}
