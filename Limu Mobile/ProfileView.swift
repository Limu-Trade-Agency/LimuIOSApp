import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    private enum Screen { case profile, kyc, edit, password, notifications, deleteAccount }

    @Binding var shouldOpenKYC: Bool
    @State private var screen: Screen = .profile
    let onLogout: () -> Void

    private var isBusinessAccount: Bool {
        appState.clientType.caseInsensitiveCompare("Business") == .orderedSame
    }

    var body: some View {
        Group {
            switch screen {
            case .profile: profile
            case .kyc: KYCView { screen = .profile }
            case .edit: EditProfileView(onBack: { screen = .profile }, onOpenKYC: { screen = .kyc })
            case .password: ChangePasswordView { screen = .profile }
            case .notifications: NotificationSettingsView { screen = .profile }
            case .deleteAccount:
                DeleteAccountView(onBack: { screen = .profile }, onDeleted: onLogout)
            }
        }
        .onAppear(perform: openKYCIfRequested)
        .task { await appState.refreshDashboard() }
        .onChange(of: shouldOpenKYC) { _, requested in
            if requested { openKYCIfRequested() }
        }
    }

    private func display(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "—" }
        return value
    }

    private var phoneText: String {
        let raw = appState.profile?.phone ?? ""
        return raw.isEmpty ? "—" : PhoneCountries.normalizedPhone(raw)
    }

    private func list(_ values: [String]?) -> String {
        display((values ?? []).joined(separator: ", "))
    }

    private var profile: some View {
        VStack(spacing: 0) {
            PageHeader {
                HStack(spacing: 12) {
                    Text("My Profile")
                        .font(.limu(size: 18, weight: .bold))
                    Spacer()
                    BrandCircleSymbol(systemName: "person.fill", diameter: 40, symbolSize: 17)
                }
            }
            ScrollView {
                VStack(spacing: 12) {
                    identityCard
                    if appState.hasCompletedKYC {
                        HStack(spacing: 10) {
                            statCard(icon: "ferry.fill", value: "\(appState.profile?.shipmentCount ?? appState.shipments.count)", label: "Total Shipments")
                            statCard(icon: "calendar", value: appState.profile?.lastShipmentDate ?? "—", label: "Last Shipment")
                        }
                    }
                    SectionCard("Personal Details") {
                    SectionCard("Personal Details") {
                        DetailRow(label: "Full Name", value: display(appState.profile?.fullName))
                        DetailRow(label: "Phone", value: phoneText)
                        DetailRow(label: "Email", value: display(appState.profile?.email))
                        DetailRow(label: "Gender", value: display(appState.profile?.gender))
                        DetailRow(label: "District", value: display(appState.profile?.location))
                        DetailRow(label: "Date of Birth", value: display(appState.profile?.dateOfBirth))
                        DetailRow(label: "Occupations", value: list(appState.profile?.occupations))
                        DetailRow(label: "Interests", value: list(appState.profile?.interests))
                        DetailRow(label: "Identification Type", value: display(appState.profile?.idType))
                        DetailRow(label: "Identification Number", value: display(appState.profile?.idNumber))
                    }
                    if isBusinessAccount {
                        SectionCard("Business Details") {
                            DetailRow(label: "Business Name", value: display(appState.profile?.businessName))
                            DetailRow(label: "Category", value: display(appState.profile?.businessCategory))
                            DetailRow(label: "Size", value: display(appState.profile?.businessSize))
                            DetailRow(label: "Sells", value: display(appState.profile?.businessOffering))
                            DetailRow(label: "Account Type", value: display(appState.profile?.clientType))
                        }
                    }
                    SectionCard("Trading Details") {
                        DetailRow(label: "Import / Export", value: display(appState.profile?.tradeIntent))
                        DetailRow(label: "Goods", value: list(appState.profile?.goodsCategories))
                        if isBusinessAccount {
                            DetailRow(label: "Services", value: list(appState.profile?.serviceCategories))
                        } else {
                            DetailRow(label: "Occupation", value: list(appState.profile?.occupations))
                            DetailRow(label: "Interests", value: list(appState.profile?.interests))
                        }
                    }
                        }
                    }
                    SectionCard("Trading Details") {
                        DetailRow(label: "Trade Intent", value: displayValue(appState.profile?.tradeIntent))
                        DetailRow(label: "Goods Categories", value: displayValue(appState.profile?.goodsCategories?.joined(separator: ", ")))
                        DetailRow(label: "Service Categories", value: displayValue(appState.profile?.serviceCategories?.joined(separator: ", ")))
                        DetailRow(label: "Notes", value: displayValue(appState.profile?.kycNotes))
                    }
                    SectionCard("Verification") {
                        HStack {
                            Text("Status").font(.limu(size: 13)).foregroundStyle(Color(hex: "374151"))
                            Spacer()
                            StatusBadge(status: appState.hasCompletedKYC ? "Completed" : "Incomplete", medium: true)
                        }
                        .padding(.bottom, 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(LimuColors.softCream).frame(height: 1) }
                        Button(appState.hasCompletedKYC ? "View KYC Details" : "Complete KYC") { screen = .kyc }
                            .font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.copper)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(LimuColors.copperWash).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(LimuColors.peach, lineWidth: 1.5) }
                            .buttonStyle(.plain).padding(.top, 10)
                    }
                    LimuCard(padding: 0) {
                        actionRow(icon: "pencil", title: "Edit Client Profile", action: openProfileEditor)
                        actionRow(icon: "lock", title: "Change Password") { screen = .password }
                        actionRow(icon: "bell", title: "Notification Settings") { screen = .notifications }
                        actionRow(icon: "hand.raised", title: "Privacy Policy", external: true) { openURL(LimuLinks.privacyPolicy) }
                        actionRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", danger: true, action: onLogout)
                        actionRow(icon: "trash", title: "Delete Account", danger: true) { screen = .deleteAccount }
                    }
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .refreshable { await appState.refreshDashboard() }
        }
        .background(LimuColors.cream)
    }

    private var identityCard: some View {
        LimuCard(padding: 16) {
            HStack(spacing: 14) {
                Text(initials)
                    .font(.limu(size: 22, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 56, height: 56).background(LimuColors.copper).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.profile?.fullName ?? "Limu Client")
                        .font(.limu(size: 17, weight: .bold))
                        .foregroundStyle(LimuColors.ink)
                    if let email = appState.profile?.email, !email.isEmpty {
                        Text(email).font(.limu(size: 12)).foregroundStyle(LimuColors.secondary)
                    }
                    Text((appState.profile?.customerCategory).map { "\($0) Client" } ?? "Client")
                        .font(.limu(size: 10, weight: .bold)).foregroundStyle(LimuColors.copper)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(LimuColors.copperWash).clipShape(Capsule())
                        .overlay { Capsule().stroke(LimuColors.copper.opacity(0.5)) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var initials: String {
        let first = appState.profile?.firstName.first.map(String.init) ?? "L"
        let last = appState.profile?.lastName.first.map(String.init) ?? "C"
        return first + last
    }

    private func openKYCIfRequested() {
        guard shouldOpenKYC else { return }
        openProfileEditor()
        shouldOpenKYC = false
    }

    private func openProfileEditor() {
        kycStep = 0
        kycCompleted = false
        screen = .clientProfile
    }

    private func displayValue(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "—" }
        return value
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        LimuCard(padding: 14) {
            VStack(spacing: 5) {
                BrandCircleSymbol(systemName: icon, diameter: 40, symbolSize: 17)
                Text(value).font(.limu(size: 16, weight: .heavy)).foregroundStyle(LimuColors.ink)
                Text(label).font(.limu(size: 10, weight: .semibold)).foregroundStyle(LimuColors.muted)
            }.frame(maxWidth: .infinity)
        }
    }

    private func actionRow(icon: String, title: String, danger: Bool = false, external: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.limu(size: 17, weight: .medium)).frame(width: 22)
                Text(title).font(.limu(size: 14, weight: .semibold))
                Spacer()
                if !danger {
                    Image(systemName: external ? "arrow.up.right" : "chevron.right")
                        .font(.limu(size: 13, weight: .bold)).foregroundStyle(Color(hex: "D1D5DB"))
                }
            }
            .foregroundStyle(danger ? LimuColors.danger : LimuColors.ink)
            .padding(.horizontal, 16).frame(height: 50)
            .overlay(alignment: .bottom) { Rectangle().fill(LimuColors.softCream).frame(height: 1) }
        }.buttonStyle(.plain)
    }
}

/// Ordinary profile details only. Identity and business details are part of the verified KYC record:
/// they are edited in the KYC flow and, once KYC is completed, changed only through a change request.
private struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    let onBack: () -> Void
    let onOpenKYC: () -> Void

    @State private var location: String
    @State private var alternatePhone: String
    @State private var tradeIntent: String
    @State private var goods: [String]
    @State private var services: [String]
    @State private var occupation: String
    @State private var interests: [String]
    @State private var options = KYCOptionsCatalog.fallback
    @State private var saved = false

    init(onBack: @escaping () -> Void, onOpenKYC: @escaping () -> Void) {
        self.onBack = onBack
        self.onOpenKYC = onOpenKYC
        // The profile is read at first appearance in `onAppear`, because `appState` is not available in `init`.
        _location = State(initialValue: "")
        _alternatePhone = State(initialValue: "")
        _tradeIntent = State(initialValue: "")
        _goods = State(initialValue: [])
        _services = State(initialValue: [])
        _occupation = State(initialValue: "")
        _interests = State(initialValue: [])
    }

    private var profile: ProfileDTO? { appState.profile }

    private var isBusiness: Bool {
        appState.clientType.caseInsensitiveCompare("Business") == .orderedSame
    }

    private var offering: String { profile?.businessOffering ?? "" }
    private var showsGoods: Bool { !isBusiness || ["Goods", "Both"].contains(offering) }
    private var showsServices: Bool { isBusiness && ["Services", "Both"].contains(offering) }

    private var alternatePhoneIsValid: Bool {
        alternatePhone.isEmpty || PhoneCountries.isValidPhone(alternatePhone)
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Profile", title: "Edit Profile", onBack: onBack)
            ScrollView {
                VStack(spacing: 14) {
                    verifiedDetails
                    DistrictPickerField(label: "District", selection: $location)
                    CountryPhoneField(label: "Alternate Phone (optional)", text: $alternatePhone)
                    ChoiceTiles(
                        label: "Import / Export",
                        options: options.tradeIntents,
                        icons: ["Import": "arrow.down", "Export": "arrow.up", "Both": "arrow.left.arrow.right"],
                        selection: $tradeIntent
                    )
                    if showsGoods {
                        MultiSelectField(
                            label: isBusiness ? "Goods Categories" : "What would you like to move?",
                            placeholder: "Select categories",
                            options: options.goodsCategories,
                            selection: $goods
                        )
                    }
                    if showsServices {
                        MultiSelectField(
                            label: "Service Categories",
                            placeholder: "Select categories",
                            options: options.serviceCategories,
                            selection: $services
                        )
                    }
                    if !isBusiness {
                        OptionPickerField(label: "Occupation", placeholder: "Select your occupation", options: options.occupations, selection: $occupation)
                        MultiSelectField(
                            label: "Interests",
                            placeholder: "Select interests",
                            options: options.interests,
                            selection: $interests
                        )
                    }
                    PrimaryButton(
                        title: appState.isBusy ? "Saving…" : saved ? "Changes Saved" : "Save Changes",
                        loading: appState.isBusy,
                        disabled: !alternatePhoneIsValid || location.isEmpty
                    ) {
                        Task { saved = await appState.updateProfile(payload) }
                    }
                }
                .padding(20)
                .padding(.bottom, 60)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(LimuColors.cream)
        .onAppear(perform: loadFromProfile)
        .task { options = await appState.loadKYCOptions() }
        .onChange(of: location) { _, _ in saved = false }
        .onChange(of: alternatePhone) { _, _ in saved = false }
        .onChange(of: tradeIntent) { _, _ in saved = false }
        .onChange(of: goods) { _, _ in saved = false }
        .onChange(of: services) { _, _ in saved = false }
        .onChange(of: occupation) { _, _ in saved = false }
        .onChange(of: interests) { _, _ in saved = false }
    }

    private var verifiedDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.limu(size: 12, weight: .bold)).foregroundStyle(LimuColors.copper)
                Text("VERIFIED DETAILS").font(.limu(size: 11, weight: .bold)).tracking(0.7).foregroundStyle(LimuColors.muted)
            }
            DetailRow(label: "Name", value: profile?.fullName ?? "—")
            DetailRow(label: "Phone", value: (profile?.phone).map { PhoneCountries.normalizedPhone($0) } ?? "—")
            DetailRow(label: "Email", value: profile?.email ?? "—")
            if isBusiness {
                DetailRow(label: "Business", value: profile?.businessName ?? "—")
            }
            Text("Your name, business and contact details are part of your KYC record. Open KYC Details to update them or request a change.")
                .font(.limu(size: 11)).foregroundStyle(LimuColors.muted).fixedSize(horizontal: false, vertical: true)
            Button("Open KYC Details", action: onOpenKYC)
                .font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.copper)
                .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LimuColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: LimuColors.charcoal.opacity(0.06), radius: 5, y: 2)
    }

    private func loadFromProfile() {
        guard let profile else { return }
        location = profile.location
        alternatePhone = profile.alternatePhones?.first.map { PhoneCountries.normalizedPhone($0) } ?? ""
        tradeIntent = profile.tradeIntent ?? ""
        goods = profile.goodsCategories ?? []
        services = profile.serviceCategories ?? []
        occupation = profile.occupations?.first ?? ""
        interests = profile.interests ?? []
        saved = false
    }

    private var payload: [String: Any] {
        var values: [String: Any] = [
            "location": location,
            "alternatePhones": alternatePhone.isEmpty ? [] : [alternatePhone],
            "tradeIntent": tradeIntent,
            "goodsCategories": showsGoods ? goods : [],
            "serviceCategories": showsServices ? services : []
        ]
        if !isBusiness {
            values["occupations"] = occupation.isEmpty ? [] : [occupation]
            values["interests"] = interests
        }
        return values
    }
    }
}

private struct ChangePasswordView: View {
    @EnvironmentObject private var appState: AppState
    let onBack: () -> Void
    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var updated = false

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Profile", title: "Change Password", onBack: onBack)
            ScrollView {
                VStack(spacing: 14) {
                    LimuTextField(label: "Current Password", placeholder: "Enter current password", text: $current, secure: true)
                    LimuTextField(label: "New Password", placeholder: "Minimum 8 characters", text: $new, secure: true)
                    LimuTextField(label: "Confirm New Password", placeholder: "Repeat new password", text: $confirm, secure: true)
                    PrimaryButton(title: appState.isBusy ? "Updating…" : updated ? "Password Updated" : "Update Password", loading: appState.isBusy, disabled: current.isEmpty || new.count < 8 || new != confirm) {
                        Task { updated = await appState.changePassword(current: current, new: new) }
                    }
                }.padding(20)
            }
        }.background(LimuColors.cream)
    }
}

private struct KYCEmailVerificationSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let email: String
    let onVerified: () -> Void

    @State private var code = ""
    @State private var sending = true
    @State private var sendFailed = false
    @State private var resent = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(LimuColors.divider).frame(width: 40, height: 5).padding(.top, 10)

            Image(systemName: "envelope.badge")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(LimuColors.copper)
                .padding(.top, 8)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Verify your email")
                    .font(.limu(size: 18, weight: .bold))
                    .foregroundStyle(LimuColors.ink)
                Text("Before completing KYC, enter the code we sent to\n\(email)")
                    .font(.limu(size: 13))
                    .foregroundStyle(LimuColors.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if sendFailed {
                Label("We couldn't send the email. Tap Resend code to try again.", systemImage: "exclamationmark.triangle.fill")
                    .font(.limu(size: 11, weight: .medium))
                    .foregroundStyle(LimuColors.warning)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "FFFBEB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            LimuTextField(label: "6-Digit Verification Code", placeholder: "000000", text: $code, keyboard: .numberPad)
                .onChange(of: code) { _, value in
                    code = String(value.filter(\.isNumber).prefix(6))
                }

            PrimaryButton(
                title: appState.isBusy ? "Verifying…" : "Verify & Complete KYC",
                loading: appState.isBusy,
                disabled: code.count != 6 || sending
            ) {
                Task {
                    if await appState.verifyKYCEmail(code: code) {
                        onVerified()
                    }
                }
            }

            Button(appState.isBusy || sending ? "Sending…" : "Resend code") {
                Task { await requestCode(isResend: true) }
            }
            .font(.limu(size: 13, weight: .semibold))
            .foregroundStyle(LimuColors.copper)
            .buttonStyle(.plain)
            .disabled(appState.isBusy || sending)

            if resent {
                Label("A new code has been sent", systemImage: "checkmark.circle.fill")
                    .font(.limu(size: 11, weight: .medium))
                    .foregroundStyle(LimuColors.success)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .background(LimuColors.cream)
        .presentationDetents([.medium, .large])
        .task { await requestCode(isResend: false) }
    }

    private func requestCode(isResend: Bool) async {
        sending = true
        defer { sending = false }
        if let response = await appState.requestKYCEmailVerification() {
            sendFailed = false
            if response.alreadyVerified == true {
                onVerified()
                return
            }
            if isResend {
                code = ""
                resent = true
            }
        } else {
            sendFailed = true
        }
    }
}

/// Account deletion, required by App Store Review Guideline 5.1.1(v).
///
/// Deliberately a two-key operation: the account password, plus the word DELETE
/// typed out. Deletion is irreversible on the server, so an accidental tap on a
/// phone someone left unlocked should not be enough to trigger it.
private struct DeleteAccountView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    let onBack: () -> Void
    let onDeleted: () -> Void

    @State private var password = ""
    @State private var confirmation = ""

    private var canDelete: Bool {
        !password.isEmpty
            && confirmation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                == AppState.accountDeletionConfirmation
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Profile", title: "Delete Account", onBack: onBack)
            ScrollView {
                VStack(spacing: 14) {
                    warning
                    SectionCard("Confirm It Is You") {
                        LimuTextField(
                            label: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            secure: true
                        )
                        LimuTextField(
                            label: "Type DELETE to confirm",
                            placeholder: AppState.accountDeletionConfirmation,
                            text: $confirmation
                        )
                        .padding(.top, 12)
                    }
                    deleteButton
                    Button("Read our privacy policy") { openURL(LimuLinks.privacyPolicy) }
                        .font(.limu(size: 12, weight: .semibold))
                        .foregroundStyle(LimuColors.copper)
                        .buttonStyle(.plain)
                }.padding(20)
            }
        }.background(LimuColors.cream)
    }

    private var warning: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("This cannot be undone", systemImage: "exclamationmark.triangle.fill")
                .font(.limu(size: 14, weight: .bold))
                .foregroundStyle(LimuColors.danger)
            Text("Deleting your account permanently removes:")
                .font(.limu(size: 13))
                .foregroundStyle(Color(hex: "374151"))
            VStack(alignment: .leading, spacing: 6) {
                bullet("Your profile and KYC details")
                bullet("Your cargo, shipment and order-form history in this app")
                bullet("Your saved sign-in and notification settings on this device")
            }
            Text("Records Limu Trade must keep for customs, tax or accounting purposes are retained as set out in our privacy policy. If you have an open consignment, speak to us before deleting.")
                .font(.limu(size: 11))
                .foregroundStyle(LimuColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LimuColors.dangerWash)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LimuColors.danger.opacity(0.25), lineWidth: 1)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(LimuColors.danger).frame(width: 4, height: 4).padding(.top, 6)
            Text(text)
                .font(.limu(size: 12))
                .foregroundStyle(Color(hex: "374151"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deleteButton: some View {
        Button {
            Task {
                if await appState.deleteAccount(password: password) { onDeleted() }
            }
        } label: {
            HStack(spacing: 8) {
                if appState.isBusy { ProgressView().tint(.white).controlSize(.small) }
                Text(appState.isBusy ? "Deleting…" : "Delete My Account")
                    .font(.limu(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(LimuColors.danger.opacity(canDelete ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canDelete || appState.isBusy)
    }
}
