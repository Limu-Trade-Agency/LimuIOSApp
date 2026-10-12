import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    private enum Screen { case profile, kyc, edit, password, deleteAccount }

    @Binding var shouldOpenKYC: Bool
    @State private var screen: Screen = .profile
    @State private var kycStep = 0
    @State private var kycCompleted = false
    let onLogout: () -> Void

    var body: some View {
        Group {
            switch screen {
            case .profile: profile
            case .kyc: KYCView(step: $kycStep, completed: $kycCompleted) { screen = .profile }
            case .edit: EditProfileView(profile: appState.profile) { screen = .profile }
            case .password: ChangePasswordView { screen = .profile }
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

    private var profile: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                VStack(spacing: 12) {
                    if appState.hasCompletedKYC {
                        HStack(spacing: 10) {
                            statCard(icon: "ferry.fill", value: "\(appState.profile?.shipmentCount ?? appState.shipments.count)", label: "Total Shipments")
                            statCard(icon: "calendar", value: appState.profile?.lastShipmentDate ?? "—", label: "Last Shipment")
                        }
                    }
                    SectionCard("Personal Details") {
                        DetailRow(label: "Full Name", value: appState.profile?.fullName ?? "—")
                        DetailRow(label: "Phone", value: appState.profile?.phone ?? "—")
                        DetailRow(label: "Email", value: appState.profile?.email ?? "—")
                        DetailRow(label: "District", value: appState.profile?.location ?? "—")
                    }
                    SectionCard("Business Details") {
                        DetailRow(label: "Business Name", value: appState.profile?.businessName ?? "—")
                        DetailRow(label: "Category", value: appState.profile?.businessCategory ?? "—")
                        DetailRow(label: "Account Type", value: appState.profile?.clientType ?? "—")
                    }
                    SectionCard("KYC Details") {
                        HStack {
                            Text("Status").font(.limu(size: 13)).foregroundStyle(Color(hex: "374151"))
                            Spacer()
                            StatusBadge(status: appState.hasCompletedKYC || kycCompleted ? "Completed" : "Incomplete", medium: true)
                        }
                        .padding(.bottom, 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(LimuColors.softCream).frame(height: 1) }
                        Button(appState.hasCompletedKYC || kycCompleted ? "View KYC Details" : "Complete KYC") { screen = .kyc }
                            .font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.copper)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(LimuColors.copperWash).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(LimuColors.peach, lineWidth: 1.5) }
                            .buttonStyle(.plain).padding(.top, 10)
                    }
                    LimuCard(padding: 0) {
                        actionRow(icon: "pencil", title: "Edit Profile") { screen = .edit }
                        actionRow(icon: "lock", title: "Change Password") { screen = .password }
                        actionRow(icon: "hand.raised", title: "Privacy Policy", external: true) { openURL(LimuLinks.privacyPolicy) }
                        actionRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", danger: true, action: onLogout)
                        actionRow(icon: "trash", title: "Delete Account", danger: true) { screen = .deleteAccount }
                    }
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 16)
                .offset(y: -12)
                .padding(.bottom, -12)
            }
        }
        .background(LimuColors.cream)
        .ignoresSafeArea(edges: .top)
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Profile").font(.limu(size: 18, weight: .bold))
            HStack(spacing: 14) {
                Text(initials)
                    .font(.limu(size: 22, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 56, height: 56).background(LimuColors.copper).clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.profile?.fullName ?? "Limu Client").font(.limu(size: 17, weight: .bold))
                    Text(appState.profile?.email ?? "").font(.limu(size: 12)).foregroundStyle(LimuColors.peach)
                    // appState.profile?.customerCategory ?? "Client" would double up on the literal
                    // "Client" suffix below when there's no category (nil profile, or a profile with
                    // no category set) — build the label instead of the plain default-then-append.
                    Text((appState.profile?.customerCategory).map { "\($0) Client" } ?? "Client")
                        .font(.limu(size: 10, weight: .bold)).foregroundStyle(LimuColors.peach)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(LimuColors.copper.opacity(0.25)).clipShape(Capsule())
                        .overlay { Capsule().stroke(LimuColors.copper.opacity(0.5)) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 64).padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background { BrandHeaderBackdrop() }
    }

    private var initials: String {
        let first = appState.profile?.firstName.first.map(String.init) ?? "L"
        let last = appState.profile?.lastName.first.map(String.init) ?? "C"
        return first + last
    }

    private func openKYCIfRequested() {
        guard shouldOpenKYC else { return }
        screen = .kyc
        shouldOpenKYC = false
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

private struct KYCView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var step: Int
    @Binding var completed: Bool
    let onBack: () -> Void

    private enum KYCStep: String {
        case personal = "Personal"
        case business = "Business"
        case categories = "Categories"
        case consent = "Consent"
    }

    private var isBusinessAccount: Bool {
        appState.clientType.caseInsensitiveCompare("Business") == .orderedSame
    }

    private var steps: [KYCStep] {
        isBusinessAccount
            ? [.personal, .business, .categories, .consent]
            : [.personal, .categories, .consent]
    }

    private var currentStep: KYCStep {
        steps[min(step, steps.count - 1)]
    }

    private var isLastStep: Bool { step == steps.count - 1 }

    @State private var firstName = "Thandiwe"
    @State private var lastName = "Banda"
    @State private var email = "thandiwe.banda@example.com"
    @State private var phone = "+265 888 000 000"
    @State private var location = "Lilongwe"
    @State private var gender = "Male"
    @State private var dateOfBirth = LimuDateFormatting.defaultDateOfBirth
    @State private var businessName = "Addo Trading Ltd"
    @State private var category = ""
    @State private var businessSize = "1–5 employees"
    @State private var businessDescription = ""
    @State private var tradeIntent = ""
    @State private var selectedCategories: Set<String> = []
    @State private var acceptedTerms = false
    @State private var loaded = false

    var body: some View {
        Group { if completed { completedView } else { form } }
            .task { await loadExistingKYC() }
            .onChange(of: appState.clientType) { _, _ in
                step = min(step, steps.count - 1)
            }
    }

    private var header: some View {
        AppHeader {
            Button(action: onBack) {
                Label("Profile", systemImage: "chevron.left").font(.limu(size: 13, weight: .medium)).foregroundStyle(LimuColors.peach)
            }.buttonStyle(.plain).padding(.bottom, 8)
            HStack {
                Text("KYC Details").font(.limu(size: 17, weight: .bold))
                Spacer()
                Text("\(appState.clientType) account")
                    .font(.limu(size: 10, weight: .bold))
                    .foregroundStyle(LimuColors.peach)
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
                .font(.limu(size: 11)).foregroundStyle(LimuColors.peach).padding(.top, 6)
        }
    }

    private var form: some View {
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
                                disabled: isCurrentStepIncomplete
                            ) {
                                Task {
                                    let success = await appState.saveKYC(payload, submit: isLastStep)
                                    if success {
                                        if isLastStep { completed = true } else { step += 1 }
                                    }
                                }
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
        .background(LimuColors.cream)
    }

    @ViewBuilder private var stepContent: some View {
        switch currentStep {
        case .personal:
            LimuTextField(label: "First Name", text: $firstName)
            LimuTextField(label: "Last Name", text: $lastName)
            LimuTextField(label: "Email", text: $email, keyboard: .emailAddress)
            menuField(label: "Gender", value: $gender, options: ["Male", "Female", "Prefer not to say"])
            DatePickerField(label: "Date of Birth", date: $dateOfBirth, range: LimuDateFormatting.dateOfBirthRange)
            CountryPhoneField(label: "Phone Number", text: $phone)
            DistrictPickerField(label: "District", selection: $location)
        case .business:
            LimuTextField(label: "Business Name", text: $businessName)
            BusinessCategoryPickerField(label: "Business Category", selection: $category)
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Business Description")
                TextEditor(text: $businessDescription).frame(height: 92).padding(8).scrollContentBackground(.hidden).background(LimuColors.white).clipShape(RoundedRectangle(cornerRadius: 10)).overlay { RoundedRectangle(cornerRadius: 10).stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5) }
            }
        case .categories:
            CategorySelectionView(tradeIntent: $tradeIntent, selection: $selectedCategories)
        case .consent:
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
                Button { acceptedTerms.toggle() } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square").font(.limu(size: 19)).foregroundStyle(acceptedTerms ? LimuColors.copper : LimuColors.muted)
                        Text("I agree to the Terms & Conditions and Privacy Policy.").font(.limu(size: 13)).foregroundStyle(Color(hex: "374151")).multilineTextAlignment(.leading)
                        Spacer()
                    }
                }.buttonStyle(.plain)
            }
        }
    }

    private var isCurrentStepIncomplete: Bool {
        switch currentStep {
        case .business:
            businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category.isEmpty
        case .categories:
            tradeIntent.isEmpty || selectedCategories.isEmpty
        case .consent:
            !acceptedTerms
        case .personal:
            !PhoneCountries.isValidPhone(phone)
        }
    }

    private var consentCopy: String {
        let details = isBusinessAccount ? "personal and business details" : "personal details"
        return "I confirm that all information provided is accurate and complete. I consent to Limu Logistics using my \(details) to provide cargo and shipment services. I understand that providing false information may result in account suspension."
    }

    private var payload: [String: Any] {
        [
            "firstName": firstName, "lastName": lastName, "email": email, "phone": phone,
            "gender": gender, "clientType": appState.clientType,
            "businessName": isBusinessAccount ? businessName : "",
            "businessCategory": isBusinessAccount ? category : "",
            "businessSize": isBusinessAccount ? businessSize : "",
            "businessOffering": isBusinessAccount ? businessDescription : "",
            "tradeIntent": tradeIntent,
            "goodsCategories": Array(selectedCategories).sorted(),
            "serviceCategories": [], "occupations": [], "interests": [], "location": location,
            "dateOfBirth": LimuDateFormatting.apiDate(from: dateOfBirth),
            "notes": "", "termsAccepted": acceptedTerms
        ]
    }

    private func loadExistingKYC() async {
        guard !loaded else { return }
        loaded = true
        if let profile = appState.profile {
            firstName = profile.firstName; lastName = profile.lastName; email = profile.email
            phone = profile.phone; location = profile.location; gender = profile.gender ?? gender
            setDateOfBirth(profile.dateOfBirth); businessName = profile.businessName
            category = profile.businessCategory
        }
        guard let record = try? await appState.loadKYC(), let value = record.submission else { return }
        firstName = value.firstName; lastName = value.lastName; email = value.email; phone = value.phone
        location = value.location; gender = value.gender; setDateOfBirth(value.dateOfBirth)
        businessName = value.businessName; category = value.businessCategory; businessSize = value.businessSize
        businessDescription = value.businessOffering; tradeIntent = value.tradeIntent ?? ""
        selectedCategories = Set(value.goodsCategories)
        acceptedTerms = value.termsAccepted
        completed = record.status.caseInsensitiveCompare("Completed") == .orderedSame
    }

    private func setDateOfBirth(_ value: String?) {
        guard let parsedDate = LimuDateFormatting.date(fromAPI: value) else { return }
        dateOfBirth = LimuDateFormatting.clamped(parsedDate, to: LimuDateFormatting.dateOfBirthRange)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title.uppercased()).font(.limu(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(LimuColors.secondary)
    }

    private func menuField(label: String, value: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label)
            Menu {
                ForEach(options, id: \.self) { option in Button(option) { value.wrappedValue = option } }
            } label: {
                HStack {
                    Text(value.wrappedValue).font(.limu(size: 14)).foregroundStyle(LimuColors.ink)
                    Spacer()
                    Image(systemName: "chevron.down").font(.limu(size: 12, weight: .semibold)).foregroundStyle(LimuColors.muted)
                }
                .padding(.horizontal, 14).frame(height: 46).background(LimuColors.white).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5) }
            }
        }
    }

    private var completedView: some View {
        VStack(spacing: 0) {
            AppHeader {
                Button(action: onBack) { Label("Profile", systemImage: "chevron.left").font(.limu(size: 13)).foregroundStyle(LimuColors.peach) }.buttonStyle(.plain)
            }
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill").font(.limu(size: 66)).foregroundStyle(LimuColors.success)
                Text("KYC Complete").font(.limu(size: 20, weight: .heavy)).foregroundStyle(LimuColors.ink)
                Text("Your details have been saved. Cargo and Shipments are available immediately.")
                    .font(.limu(size: 14)).foregroundStyle(LimuColors.secondary).multilineTextAlignment(.center).lineSpacing(4)
                StatusBadge(status: "Completed", medium: true)
                Button("Edit KYC Details") {
                    step = 0
                    completed = false
                }
                .font(.limu(size: 14, weight: .bold))
                .foregroundStyle(LimuColors.copper)
                Button("Back to Profile", action: onBack).font(.limu(size: 15, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 32).padding(.vertical, 13).background(LimuColors.copper).clipShape(RoundedRectangle(cornerRadius: 12)).buttonStyle(.plain).padding(.top, 12)
            }
            .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(LimuColors.cream)
    }
}

private struct CategorySelectionView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var tradeIntent: String
    @Binding var selection: Set<String>
    @State private var search = ""
    @State private var categories: [CategoryDTO] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private let intents = [
        ("Import", "arrow.down"),
        ("Export", "arrow.up"),
        ("Both", "arrow.left.arrow.right")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("How do you plan to trade?")
                    .font(.limu(size: 16, weight: .bold))
                    .foregroundStyle(LimuColors.ink)
                Text("Tell us whether you want to import, export, or do both.")
                    .font(.limu(size: 12))
                    .foregroundStyle(LimuColors.secondary)
            }

            HStack(spacing: 8) {
                ForEach(intents, id: \.0) { intent in
                    Button {
                        tradeIntent = intent.0
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: intent.1)
                                .font(.limu(size: 16, weight: .bold))
                            Text(intent.0)
                                .font(.limu(size: 12, weight: .bold))
                        }
                        .foregroundStyle(tradeIntent == intent.0 ? .white : LimuColors.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(tradeIntent == intent.0 ? LimuColors.copper : LimuColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(tradeIntent == intent.0 ? LimuColors.copper : LimuColors.charcoal.opacity(0.14), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(intent.0) goods")
                    .accessibilityAddTraits(tradeIntent == intent.0 ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("WHAT WOULD YOU LIKE TO MOVE?")
                    .font(.limu(size: 12, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(LimuColors.secondary)
                Text("Search and select all categories that interest you.")
                    .font(.limu(size: 11))
                    .foregroundStyle(LimuColors.muted)
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LimuColors.muted)
                    TextField("Search categories", text: $search)
                        .font(.limu(size: 14))
                        .foregroundStyle(LimuColors.ink)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(LimuColors.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear category search")
                    }
                }
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(LimuColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5)
                }
            }

            if !selection.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("SELECTED · \(selection.count)")
                        .font(.limu(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(LimuColors.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(selection.sorted(), id: \.self) { category in
                                Button {
                                    selection.remove(category)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(category)
                                        Image(systemName: "xmark")
                                            .font(.limu(size: 9, weight: .bold))
                                    }
                                    .font(.limu(size: 11, weight: .semibold))
                                    .foregroundStyle(LimuColors.copper)
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .background(LimuColors.copperWash)
                                    .clipShape(Capsule())
                                    .overlay { Capsule().stroke(LimuColors.peach, lineWidth: 1) }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(category)")
                            }
                        }
                    }
                }
            }

            categoryResults
        }
        .task(id: search) { await loadCategories() }
    }

    @ViewBuilder private var categoryResults: some View {
        LimuCard(padding: 0) {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().tint(LimuColors.copper)
                    Text("Loading categories…")
                        .font(.limu(size: 12))
                        .foregroundStyle(LimuColors.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 72)
            } else if let loadError {
                VStack(spacing: 8) {
                    Text(loadError)
                        .font(.limu(size: 12))
                        .foregroundStyle(LimuColors.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { Task { await loadCategories(skipDelay: true) } }
                        .font(.limu(size: 12, weight: .bold))
                        .foregroundStyle(LimuColors.copper)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            } else if categories.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LimuColors.muted)
                    Text(search.isEmpty ? "No categories are available yet." : "No categories match ‘\(search)’." )
                        .font(.limu(size: 12))
                        .foregroundStyle(LimuColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
            } else {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    Button {
                        if selection.contains(category.name) {
                            selection.remove(category.name)
                        } else {
                            selection.insert(category.name)
                        }
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: selection.contains(category.name) ? "checkmark.circle.fill" : "circle")
                                .font(.limu(size: 18, weight: .semibold))
                                .foregroundStyle(selection.contains(category.name) ? LimuColors.copper : LimuColors.muted)
                            Text(category.name)
                                .font(.limu(size: 13, weight: .medium))
                                .foregroundStyle(LimuColors.ink)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .overlay(alignment: .bottom) {
                            if index < categories.count - 1 {
                                Rectangle().fill(LimuColors.softCream).frame(height: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection.contains(category.name) ? .isSelected : [])
                }
            }
        }
    }

    private func loadCategories(skipDelay: Bool = false) async {
        isLoading = true
        loadError = nil
        if !skipDelay {
            do { try await Task.sleep(nanoseconds: 250_000_000) }
            catch { return }
        }
        guard !Task.isCancelled else { return }
        do {
            categories = try await appState.loadCategories(query: search)
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            categories = []
            loadError = "Categories could not be loaded."
            isLoading = false
        }
    }
}

private struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    let onBack: () -> Void
    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String
    @State private var location: String
    @State private var business: String
    @State private var saved = false

    init(profile: ProfileDTO?, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _firstName = State(initialValue: profile?.firstName ?? "")
        _lastName = State(initialValue: profile?.lastName ?? "")
        _phone = State(initialValue: profile?.phone ?? "")
        _location = State(initialValue: profile?.location ?? "")
        _business = State(initialValue: profile?.businessName ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Profile", title: "Edit Profile", onBack: onBack)
            ScrollView {
                VStack(spacing: 14) {
                    LimuTextField(label: "First Name", text: $firstName)
                    LimuTextField(label: "Last Name", text: $lastName)
                    CountryPhoneField(label: "Phone Number", text: $phone)
                    DistrictPickerField(label: "District", selection: $location)
                    LimuTextField(label: "Business Name", text: $business)
                    PrimaryButton(
                        title: appState.isBusy ? "Saving…" : saved ? "Changes Saved" : "Save Changes",
                        loading: appState.isBusy,
                        disabled: !PhoneCountries.isValidPhone(phone)
                    ) {
                        Task {
                            saved = await appState.updateProfile(["firstName": firstName, "lastName": lastName, "phone": phone, "location": location, "businessName": business])
                        }
                    }
                }.padding(20)
            }
        }.background(LimuColors.cream)
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
