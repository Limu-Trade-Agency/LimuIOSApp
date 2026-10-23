import SwiftUI

// KYC is the one place a client's identity and business details are captured. Before KYC is
// completed it is a staged form that saves a draft at every step. Once completed, those details
// are locked (they are the verified record): the client reviews them read-only and files a change
// request, which staff approve in the portal. Ordinary preferences live in Edit Profile.

enum KYCStep: String, CaseIterable {
    case personal = "Personal"
    case business = "Business"
    case trade = "Trade"
    case consent = "Consent"
}

struct KYCForm: Equatable {
    var firstName = ""
    var lastName = ""
    var gender = ""
    var dateOfBirth = LimuDateFormatting.defaultDateOfBirth
    /// False until a date is picked, so the default date is never submitted by accident.
    var hasDateOfBirth = false
    var location = ""
    var occupation = ""
    var interests: [String] = []
    var businessName = ""
    var businessCategory = ""
    var businessSize = ""
    var businessOffering = ""
    var tradeIntent = ""
    var goodsCategories: [String] = []
    var serviceCategories: [String] = []
    var acceptedTerms = false

    init() {}

    init(profile: ProfileDTO?) {
        guard let profile else { return }
        firstName = profile.firstName
        lastName = profile.lastName
        gender = profile.gender ?? ""
        setDateOfBirth(profile.dateOfBirth)
        location = profile.location
        occupation = profile.occupations?.first ?? ""
        interests = profile.interests ?? []
        businessName = profile.businessName
        businessCategory = profile.businessCategory
        businessSize = profile.businessSize ?? ""
        businessOffering = profile.businessOffering ?? ""
        tradeIntent = profile.tradeIntent ?? ""
        goodsCategories = profile.goodsCategories ?? []
        serviceCategories = profile.serviceCategories ?? []
    }

    init(submission value: KYCSubmissionDTO) {
        firstName = value.firstName
        lastName = value.lastName
        gender = value.gender
        setDateOfBirth(value.dateOfBirth)
        location = value.location
        occupation = value.occupations.first ?? ""
        interests = value.interests
        businessName = value.businessName
        businessCategory = value.businessCategory
        businessSize = value.businessSize
        businessOffering = value.businessOffering
        tradeIntent = value.tradeIntent ?? ""
        goodsCategories = value.goodsCategories
        serviceCategories = value.serviceCategories
        acceptedTerms = value.termsAccepted
    }

    private mutating func setDateOfBirth(_ value: String?) {
        // Older records can carry a full timestamp; only the date part matters.
        guard let value, let date = LimuDateFormatting.date(fromAPI: String(value.prefix(10))) else { return }
        dateOfBirth = LimuDateFormatting.clamped(date, to: LimuDateFormatting.dateOfBirthRange)
        hasDateOfBirth = true
    }

    var isAdult: Bool { dateOfBirth <= LimuDateFormatting.adultDateOfBirthRange.upperBound }

    /// Goods are asked of every personal account and of businesses that sell goods.
    func needsGoods(business: Bool) -> Bool {
        !business || ["Goods", "Both"].contains(businessOffering)
    }

    func needsServices(business: Bool) -> Bool {
        business && ["Services", "Both"].contains(businessOffering)
    }

    func isComplete(_ step: KYCStep, business: Bool) -> Bool {
        func filled(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        switch step {
        case .personal:
            return filled(firstName) && filled(lastName) && filled(gender) && filled(location)
                && hasDateOfBirth && isAdult && (business || filled(occupation))
        case .business:
            return filled(businessName) && filled(businessCategory) && filled(businessSize) && filled(businessOffering)
        case .trade:
            return filled(tradeIntent)
                && (!needsGoods(business: business) || !goodsCategories.isEmpty)
                && (!needsServices(business: business) || !serviceCategories.isEmpty)
        case .consent:
            return acceptedTerms
        }
    }

    /// Phone and email are deliberately absent: they are the verified account identifiers and the
    /// server keeps them as they are.
    func payload(business: Bool) -> [String: Any] {
        [
            "firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            "lastName": lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            "gender": gender,
            "dateOfBirth": hasDateOfBirth ? LimuDateFormatting.apiDate(from: dateOfBirth) : "",
            "location": location,
            "occupations": business || occupation.isEmpty ? [] : [occupation],
            "interests": business ? [] : interests,
            "businessName": business ? businessName.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            "businessCategory": business ? businessCategory : "",
            "businessSize": business ? businessSize : "",
            "businessOffering": business ? businessOffering : "",
            "tradeIntent": tradeIntent,
            "goodsCategories": needsGoods(business: business) ? goodsCategories : [],
            "serviceCategories": needsServices(business: business) ? serviceCategories : [],
            "termsAccepted": acceptedTerms
        ]
    }
}

struct KYCView: View {
    @EnvironmentObject private var appState: AppState
    let onBack: () -> Void
    /// A reactivating account can do nothing but this form, so "back" means signing out.
    var isReactivation = false

    private var backTitle: String { isReactivation ? "Sign Out" : "Profile" }

    private enum Phase { case loading, form, summary, changeRequest, done }

    @State private var phase: Phase = .loading
    @State private var step = 0
    @State private var form = KYCForm()
    @State private var options = KYCOptionsCatalog.fallback
    @State private var record: KYCRecordDTO?

    private var isBusiness: Bool {
        appState.clientType.caseInsensitiveCompare("Business") == .orderedSame
    }

    private var steps: [KYCStep] {
        isBusiness ? [.personal, .business, .trade, .consent] : [.personal, .trade, .consent]
    }

    private var currentStep: KYCStep { steps[min(step, steps.count - 1)] }
    private var isLastStep: Bool { step >= steps.count - 1 }

    var body: some View {
        Group {
            switch phase {
            case .loading: loadingView
            case .form: formView
            case .summary: KYCSummaryView(form: form, record: record, isBusiness: isBusiness, onBack: onBack) { phase = .changeRequest }
            case .changeRequest:
                KYCChangeRequestView(original: form, options: options, isBusiness: isBusiness, onCancel: { phase = .summary }) {
                    Task {
                        await reloadRecord()
                        phase = .summary
                    }
                }
            case .done: doneView
            }
        }
        .task { await load() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: backTitle, title: "KYC Details", onBack: onBack)
            ProgressView().tint(LimuColors.copper).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(LimuColors.pageBackground)
    }

    private func load() async {
        guard phase == .loading else { return }
        options = await appState.loadKYCOptions()
        if let loaded = try? await appState.loadKYC() {
            record = loaded
            form = loaded.submission.map(KYCForm.init(submission:)) ?? KYCForm(profile: appState.profile)
        } else {
            form = KYCForm(profile: appState.profile)
        }
        let locked = record?.locked ?? appState.hasCompletedKYC
        if locked {
            phase = .summary
        } else {
            // Resume a draft at the first step that still needs an answer.
            step = steps.firstIndex { !form.isComplete($0, business: isBusiness) } ?? 0
            phase = .form
        }
    }

    private func reloadRecord() async {
        guard let loaded = try? await appState.loadKYC() else { return }
        record = loaded
        if let submission = loaded.submission { form = KYCForm(submission: submission) }
    }

    // MARK: - Staged form

    private var header: some View {
        AppHeader {
            Button(action: onBack) {
                Label(backTitle, systemImage: "chevron.left").font(.limu(size: 13, weight: .medium)).foregroundStyle(LimuColors.secondary)
            }.buttonStyle(.plain).padding(.bottom, 8)
            HStack {
                Text("KYC Details").font(.limu(size: 17, weight: .bold))
                Spacer()
                Text("\(appState.clientType) account")
                    .font(.limu(size: 10, weight: .bold))
                    .foregroundStyle(LimuColors.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(LimuColors.copper.opacity(0.24))
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(LimuColors.copper.opacity(0.5)) }
            }
            .padding(.bottom, 12)
            HStack(spacing: 4) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule().fill(index <= step ? LimuColors.copper : LimuColors.peach.opacity(0.3)).frame(height: 4)
                }
            }
            Text("Step \(step + 1) of \(steps.count): \(currentStep.rawValue)")
                .font(.limu(size: 11)).foregroundStyle(LimuColors.secondary).padding(.top, 6)
        }
    }

    private var formView: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        Color.clear.frame(height: 0).id("kyc-form-top")
                        stepContent
                        HStack(spacing: 10) {
                            if step > 0 {
                                Button("Back") { step -= 1 }
                                    .font(.limu(size: 14, weight: .bold)).foregroundStyle(Color(hex: "482A28"))
                                    .frame(maxWidth: .infinity).frame(height: 46).background(Color(hex: "F5EEE6")).clipShape(RoundedRectangle(cornerRadius: 12)).buttonStyle(.plain)
                            }
                            PrimaryButton(
                                title: isLastStep ? "Complete KYC" : "Continue",
                                loading: appState.isBusy,
                                disabled: !form.isComplete(currentStep, business: isBusiness)
                            ) {
                                Task { await advance() }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .padding(.bottom, 150)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: step) { _, _ in
                    proxy.scrollTo("kyc-form-top", anchor: .top)
                }
            }
        }
        .background(LimuColors.pageBackground)
    }

    private func advance() async {
        let success = await appState.saveKYC(form.payload(business: isBusiness), submit: isLastStep)
        guard success else { return }
        if isLastStep {
            await reloadRecord()
            phase = .done
        } else {
            step += 1
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch currentStep {
        case .personal: personalStep
        case .business: businessStep
        case .trade: tradeStep
        case .consent: consentStep
        }
    }

    @ViewBuilder private var personalStep: some View {
        if appState.isReactivating {
            Label("Welcome back. Confirm your details below to reactivate your original account. Your shipment history stays with it.", systemImage: "arrow.clockwise.circle.fill")
                .font(.limu(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "482A28"))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LimuColors.copperWash)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        LimuTextField(label: "First Name", text: $form.firstName)
        LimuTextField(label: "Last Name", text: $form.lastName)
        ChoiceTiles(label: "Gender", options: options.genders, selection: $form.gender)
        DatePickerField(
            label: "Date of Birth",
            date: $form.dateOfBirth,
            range: LimuDateFormatting.adultDateOfBirthRange,
            isSet: $form.hasDateOfBirth,
            placeholder: "Select your date of birth"
        )
        DistrictPickerField(label: "District", selection: $form.location)
        if !isBusiness {
            OptionPickerField(label: "Occupation", placeholder: "Select your occupation", options: options.occupations, selection: $form.occupation)
        }
        ReadOnlyField(
            label: "Phone Number",
            value: PhoneCountries.normalizedPhone(appState.profile?.phone ?? ""),
            note: "This is the number you verified when you registered."
        )
        ReadOnlyField(label: "Email", value: appState.profile?.email ?? "")
    }

    @ViewBuilder private var businessStep: some View {
        LimuTextField(label: "Business Name", text: $form.businessName)
        OptionPickerField(label: "Business Category", placeholder: "Select a business category", options: options.businessCategories, selection: $form.businessCategory)
        ChoiceList(label: "Business Size", options: options.businessSizes, selection: $form.businessSize)
        ChoiceTiles(label: "What does the business sell?", options: options.businessOfferings, selection: $form.businessOffering)
    }

    @ViewBuilder private var tradeStep: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("How do you plan to trade?").font(.limu(size: 16, weight: .bold)).foregroundStyle(LimuColors.ink)
            Text("Tell us whether you want to import, export, or do both.").font(.limu(size: 12)).foregroundStyle(LimuColors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        ChoiceTiles(
            options: options.tradeIntents,
            icons: ["Import": "arrow.down", "Export": "arrow.up", "Both": "arrow.left.arrow.right"],
            selection: $form.tradeIntent
        )
        if form.needsGoods(business: isBusiness) {
            MultiSelectField(
                label: isBusiness ? "Goods Categories" : "What would you like to move?",
                hint: "Select all that apply.",
                placeholder: "Select categories",
                options: options.goodsCategories,
                selection: $form.goodsCategories
            )
        }
        if form.needsServices(business: isBusiness) {
            MultiSelectField(
                label: "Service Categories",
                hint: "Select all that apply.",
                placeholder: "Select categories",
                options: options.serviceCategories,
                selection: $form.serviceCategories
            )
        }
        if !isBusiness {
            MultiSelectField(
                label: "Interests",
                hint: "Optional. Helps us tailor updates for you.",
                placeholder: "Select interests",
                options: options.interests,
                selection: $form.interests
            )
        }
    }

    @ViewBuilder private var consentStep: some View {
        VStack(spacing: 14) {
            LimuCard {
                Text("Terms & Conditions").font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink).padding(.bottom, 8)
                Text(consentCopy)
                    .font(.limu(size: 12)).foregroundStyle(Color(hex: "374151")).lineSpacing(5)
            }
            HStack(spacing: 14) {
                Link("Read the full Terms & Conditions", destination: LimuLinks.terms)
                Link("Privacy Policy", destination: LimuLinks.privacyPolicy)
            }
            .font(.limu(size: 12, weight: .semibold))
            .tint(LimuColors.copper)
            Button { form.acceptedTerms.toggle() } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: form.acceptedTerms ? "checkmark.square.fill" : "square").font(.limu(size: 19)).foregroundStyle(form.acceptedTerms ? LimuColors.copper : LimuColors.muted)
                    Text("I agree to the Terms & Conditions and Privacy Policy.").font(.limu(size: 13)).foregroundStyle(Color(hex: "374151")).multilineTextAlignment(.leading)
                    Spacer()
                }
            }.buttonStyle(.plain)
        }
    }

    private var consentCopy: String {
        let details = isBusiness ? "personal and business details" : "personal details"
        return "I confirm that all information provided is accurate and complete. I consent to Limu Logistics using my \(details) to provide cargo and shipment services. I understand that providing false information may result in account suspension."
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 0) {
            AppHeader {
                Button(action: onBack) { Label(backTitle, systemImage: "chevron.left").font(.limu(size: 13)).foregroundStyle(LimuColors.secondary) }.buttonStyle(.plain)
            }
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill").font(.limu(size: 66)).foregroundStyle(LimuColors.success)
                Text("KYC Complete").font(.limu(size: 20, weight: .heavy)).foregroundStyle(LimuColors.ink)
                Text("Your details are verified and saved to your Limu account. Shipments and invoices are available now.")
                    .font(.limu(size: 14)).foregroundStyle(LimuColors.secondary).multilineTextAlignment(.center).lineSpacing(4)
                StatusBadge(status: "Completed", medium: true)
                Button("View KYC Details") { phase = .summary }
                    .font(.limu(size: 14, weight: .bold))
                    .foregroundStyle(LimuColors.copper)
                Button("Back to Profile", action: onBack).font(.limu(size: 15, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 32).padding(.vertical, 13).background(LimuColors.copper).clipShape(RoundedRectangle(cornerRadius: 12)).buttonStyle(.plain).padding(.top, 12)
            }
            .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(LimuColors.pageBackground)
    }
}

// MARK: - Locked summary

struct KYCSummaryView: View {
    let form: KYCForm
    let record: KYCRecordDTO?
    let isBusiness: Bool
    let onBack: () -> Void
    let onRequestChange: () -> Void

    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Profile", title: "KYC Details", subtitle: "Verified record", status: "Completed", onBack: onBack)
            ScrollView {
                VStack(spacing: 12) {
                    if let pending = record?.pendingChangeRequest, pending.status == "Pending" {
                        pendingBanner(pending)
                    }
                    SectionCard("Personal Details") {
                        DetailRow(label: "Name", value: "\(form.firstName) \(form.lastName)")
                        DetailRow(label: "Gender", value: display(form.gender))
                        DetailRow(label: "Date of Birth", value: form.hasDateOfBirth ? LimuDateFormatting.displayDate(form.dateOfBirth) : "—")
                        DetailRow(label: "Phone", value: display(PhoneCountries.normalizedPhone(appState.profile?.phone ?? "")))
                        DetailRow(label: "Email", value: display(appState.profile?.email ?? ""))
                        DetailRow(label: "District", value: display(form.location))
                        if !isBusiness {
                            DetailRow(label: "Occupation", value: display(form.occupation))
                        }
                    }
                    if isBusiness {
                        SectionCard("Business Details") {
                            DetailRow(label: "Business Name", value: display(form.businessName))
                            DetailRow(label: "Category", value: display(form.businessCategory))
                            DetailRow(label: "Size", value: display(form.businessSize))
                            DetailRow(label: "Sells", value: display(form.businessOffering))
                        }
                    }
                    SectionCard("Trade") {
                        DetailRow(label: "Import / Export", value: display(form.tradeIntent))
                        if form.needsGoods(business: isBusiness) {
                            DetailRow(label: "Goods", value: display(form.goodsCategories.joined(separator: ", ")))
                        }
                        if form.needsServices(business: isBusiness) {
                            DetailRow(label: "Services", value: display(form.serviceCategories.joined(separator: ", ")))
                        }
                        if !isBusiness {
                            DetailRow(label: "Interests", value: display(form.interests.joined(separator: ", ")))
                        }
                    }
                    lockNotice
                    PrimaryButton(title: record?.pendingChangeRequest?.status == "Pending" ? "Replace My Change Request" : "Request a Change", action: onRequestChange)
                    Color.clear.frame(height: 24)
                }
                .padding(16)
            }
        }
        .background(LimuColors.pageBackground)
    }

    private func display(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value
    }

    private var lockNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill").font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.copper)
            Text("These details are your verified KYC record, so they can only be changed through a request that Limu reviews. Your district, trade preferences and interests can be updated any time from Edit Profile.")
                .font(.limu(size: 12)).foregroundStyle(LimuColors.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LimuColors.copperWash)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func pendingBanner(_ request: KYCChangeRequestDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark").foregroundStyle(LimuColors.warning)
                Text("Change request pending review").font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
            }
            ForEach(request.changes.keys.sorted(), id: \.self) { key in
                if let change = request.changes[key] {
                    Text("\(KYCChangeRequestView.label(for: key)): \(change.from.isEmpty ? "—" : change.from) → \(change.to.isEmpty ? "—" : change.to)")
                        .font(.limu(size: 12)).foregroundStyle(Color(hex: "374151"))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFFBEB"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "F59E0B").opacity(0.4)) }
    }
}

// MARK: - Change request

struct KYCChangeRequestView: View {
    @EnvironmentObject private var appState: AppState
    let original: KYCForm
    let options: KYCOptionsDTO
    let isBusiness: Bool
    let onCancel: () -> Void
    let onSubmitted: () -> Void

    @State private var draft: KYCForm
    @State private var reason = ""

    init(original: KYCForm, options: KYCOptionsDTO, isBusiness: Bool, onCancel: @escaping () -> Void, onSubmitted: @escaping () -> Void) {
        self.original = original
        self.options = options
        self.isBusiness = isBusiness
        self.onCancel = onCancel
        self.onSubmitted = onSubmitted
        _draft = State(initialValue: original)
    }

    static func label(for field: String) -> String {
        switch field {
        case "firstName": "First name"
        case "lastName": "Last name"
        case "phone": "Phone number"
        case "dateOfBirth": "Date of birth"
        case "gender": "Gender"
        case "clientType": "Account type"
        case "businessName": "Business name"
        case "businessCategory": "Business category"
        case "businessSize": "Business size"
        case "businessOffering": "Goods or services"
        default: field
        }
    }

    private func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Only the details that actually differ are sent.
    private var changes: [String: Any] {
        var result: [String: Any] = [:]
        if trimmed(draft.firstName) != trimmed(original.firstName) { result["firstName"] = trimmed(draft.firstName) }
        if trimmed(draft.lastName) != trimmed(original.lastName) { result["lastName"] = trimmed(draft.lastName) }
        if draft.gender != original.gender { result["gender"] = draft.gender }
        if draft.hasDateOfBirth, LimuDateFormatting.apiDate(from: draft.dateOfBirth) != LimuDateFormatting.apiDate(from: original.dateOfBirth) || !original.hasDateOfBirth {
            result["dateOfBirth"] = LimuDateFormatting.apiDate(from: draft.dateOfBirth)
        }
        if isBusiness {
            if trimmed(draft.businessName) != trimmed(original.businessName) { result["businessName"] = trimmed(draft.businessName) }
            if draft.businessCategory != original.businessCategory { result["businessCategory"] = draft.businessCategory }
            if draft.businessSize != original.businessSize { result["businessSize"] = draft.businessSize }
            if draft.businessOffering != original.businessOffering { result["businessOffering"] = draft.businessOffering }
        }
        return result
    }

    private var canSubmit: Bool {
        !changes.isEmpty
            && trimmed(reason).count >= 5
            && !trimmed(draft.firstName).isEmpty
            && !trimmed(draft.lastName).isEmpty
            && (!isBusiness || (!trimmed(draft.businessName).isEmpty && !draft.businessCategory.isEmpty))
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "KYC Details", title: "Request a Change", subtitle: "Limu reviews every change to verified details", onBack: onCancel)
            ScrollView {
                VStack(spacing: 14) {
                    LimuTextField(label: "First Name", text: $draft.firstName)
                    LimuTextField(label: "Last Name", text: $draft.lastName)
                    ChoiceTiles(label: "Gender", options: options.genders, selection: $draft.gender)
                    DatePickerField(
                        label: "Date of Birth",
                        date: $draft.dateOfBirth,
                        range: LimuDateFormatting.adultDateOfBirthRange,
                        isSet: $draft.hasDateOfBirth,
                        placeholder: "Select your date of birth"
                    )
                    if isBusiness {
                        LimuTextField(label: "Business Name", text: $draft.businessName)
                        OptionPickerField(label: "Business Category", placeholder: "Select a business category", options: options.businessCategories, selection: $draft.businessCategory)
                        ChoiceList(label: "Business Size", options: options.businessSizes, selection: $draft.businessSize)
                        ChoiceTiles(label: "What does the business sell?", options: options.businessOfferings, selection: $draft.businessOffering)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("REASON FOR THE CHANGE")
                            .font(.limu(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(LimuColors.secondary)
                        TextEditor(text: $reason)
                            .frame(height: 92).padding(8).scrollContentBackground(.hidden)
                            .background(LimuColors.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5) }
                    }
                    Text("To change your registered phone number or email, contact Limu support.")
                        .font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PrimaryButton(title: "Submit Request", loading: appState.isBusy, disabled: !canSubmit) {
                        Task {
                            let sent = await appState.requestKYCChange(changes, reason: trimmed(reason))
                            if sent != nil { onSubmitted() }
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(LimuColors.pageBackground)
    }
}
