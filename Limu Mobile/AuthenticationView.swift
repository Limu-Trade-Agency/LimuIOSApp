import SwiftUI

struct AuthenticationView: View {
    enum Mode { case signIn, register, verifyEmail, forgot, reset, resetPassword, claim }

    @State private var mode: Mode = .signIn
    @State private var registerStep = 0
    @State private var keyboardVisible = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var location = ""
    @State private var confirmPassword = ""
    @State private var clientType = "Business"
    @State private var businessName = ""
    @State private var stayLoggedIn = false
    @State private var isLoading = false
    @State private var oneTimeToken = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var resetIdentifier = ""
    @State private var resetCode = ""
    @State private var resetResent = false
    @State private var verificationEmail = ""
    @State private var verificationPhone = ""
    @State private var verificationIdentifier = ""
    @State private var verificationChannel = "whatsapp"
    @State private var verificationCode = ""
    @State private var verificationResent = false
    @State private var verificationCodeSent = true
    @State private var verificationLinkedAccount = false

    private var isWhatsAppChannel: Bool { ["whatsapp", "sms"].contains(verificationChannel) }

    let onLogin: () -> Void
    @EnvironmentObject private var appState: AppState

    init(onLogin: @escaping () -> Void) {
        self.onLogin = onLogin
    }

    private var passwordHasUppercase: Bool {
        password.range(of: "[A-Z]", options: .regularExpression) != nil
    }

    private var passwordHasNumber: Bool {
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }

    private var passwordHasSpecialCharacter: Bool {
        password.range(of: "[^A-Za-z0-9\\s]", options: .regularExpression) != nil
    }

    private var isRegistrationPasswordValid: Bool {
        password.count >= 6
            && passwordHasUppercase
            && passwordHasNumber
            && passwordHasSpecialCharacter
    }

    private var isRegistrationPhoneValid: Bool {
        PhoneCountries.isValidPhone(phone)
    }

    private var newPasswordHasLetter: Bool {
        newPassword.range(of: "[A-Za-z]", options: .regularExpression) != nil
    }

    private var newPasswordHasNumber: Bool {
        newPassword.range(of: "[0-9]", options: .regularExpression) != nil
    }

    private var isNewPasswordValid: Bool {
        newPassword.count >= 8 && newPasswordHasLetter && newPasswordHasNumber
    }

    var body: some View {
        VStack(spacing: 0) {
            if mode == .verifyEmail { verificationHeader }
            else if [.forgot, .reset, .resetPassword, .claim].contains(mode) { forgotHeader }
            else if keyboardVisible { compactHeader }
            else { heroHeader }
            if mode == .signIn || mode == .register { authTabs }
            ScrollView {
                Group {
                    switch mode {
                    case .signIn: signInForm
                    case .register: registerForm
                    case .verifyEmail: verificationForm
                    case .forgot: forgotForm
                    case .reset: resetCodeForm
                    case .resetPassword: resetPasswordForm
                    case .claim: claimForm
                    }
                }
                .padding(24)
                .padding(.bottom, keyboardVisible ? 40 : 0)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(LimuColors.cream.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { keyboardVisible = false }
        }
    }

    /// Slim brand bar shown while the keyboard is up so the fields keep the room.
    private var compactHeader: some View {
        LimuOutlineLogoMark(width: 72)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background { BrandHeaderBackdrop() }
            .overlay(alignment: .bottom) {
                Rectangle().fill(LimuColors.brandGradient).frame(height: 3)
            }
    }

    private var heroHeader: some View {
        VStack(spacing: 0) {
            LimuOutlineLogoMark(width: 128)
                .offset(x: 12)
                .padding(.top, 18)
                .padding(.bottom, 12)
            Text("Client Portal")
                .font(.limu(size: 22, weight: .bold))
            Text("Track your cargo and shipments")
                .font(.limu(size: 13))
                .foregroundStyle(LimuColors.peach)
                .padding(.top, 4)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .background { BrandHeaderBackdrop() }
        .overlay(alignment: .bottom) {
            Rectangle().fill(LimuColors.brandGradient).frame(height: 3)
        }
    }

    private var forgotHeader: some View {
        AppHeader {
            Button {
                if mode == .resetPassword {
                    mode = .reset
                    newPassword = ""
                    confirmNewPassword = ""
                    appState.clearError()
                } else {
                    returnToSignIn()
                }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.limu(size: 14, weight: .medium))
                    .foregroundStyle(LimuColors.peach)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
            Text(authHeaderTitle)
                .font(.limu(size: 22, weight: .bold))
            Text(authHeaderSubtitle)
                .font(.limu(size: 13))
                .foregroundStyle(LimuColors.peach)
                .padding(.top, 4)
        }
    }

    private var authHeaderTitle: String {
        switch mode {
        case .claim: return "Claim Account"
        case .reset: return "Enter Verification Code"
        case .resetPassword: return "Create New Password"
        default: return "Reset Password"
        }
    }

    private var authHeaderSubtitle: String {
        switch mode {
        case .claim: return "Connect your existing Limu client record"
        case .reset: return "Step 1 of 2: confirm it's you"
        case .resetPassword: return "Step 2 of 2: choose a new password"
        default: return "We'll send a verification code by email and WhatsApp"
        }
    }

    private var verificationHeader: some View {
        AppHeader {
            Button {
                mode = .register
                registerStep = 2
                verificationCode = ""
                verificationResent = false
                verificationCodeSent = true
                appState.clearError()
            } label: {
                Label("Registration", systemImage: "chevron.left")
                    .font(.limu(size: 14, weight: .medium))
                    .foregroundStyle(LimuColors.peach)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
            Text(isWhatsAppChannel ? "Verify Your Number" : "Verify Your Email")
                .font(.limu(size: 22, weight: .bold))
            Text("One quick step to secure your account")
                .font(.limu(size: 13))
                .foregroundStyle(LimuColors.peach)
                .padding(.top, 4)
        }
    }

    private var authTabs: some View {
        HStack(spacing: 0) {
            authTab("Sign In", selected: mode == .signIn) { mode = .signIn }
            authTab("Register", selected: mode == .register) { mode = .register; registerStep = 0 }
        }
        .background(LimuColors.white)
        .overlay(alignment: .bottom) { Rectangle().fill(LimuColors.charcoal.opacity(0.1)).frame(height: 1) }
    }

    private func authTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.limu(size: 14, weight: .semibold))
                .foregroundStyle(selected ? LimuColors.copper : LimuColors.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selected ? LimuColors.copper : .clear).frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            LimuTextField(label: "Email or Phone", text: $email, keyboard: .emailAddress)
            VStack(alignment: .leading, spacing: 0) {
                LimuTextField(label: "Password", text: $password, secure: true)
                Button("Forgot password?") { mode = .forgot }
                    .font(.limu(size: 12, weight: .semibold))
                    .foregroundStyle(LimuColors.copper)
                    .buttonStyle(.plain)
                    .padding(.top, 8)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stay logged in")
                        .font(.limu(size: 13, weight: .semibold))
                        .foregroundStyle(LimuColors.ink)
                    Text("Skip sign-in on your next visit")
                        .font(.limu(size: 11))
                        .foregroundStyle(LimuColors.muted)
                }
                Spacer()
                Button { stayLoggedIn.toggle() } label: {
                    ZStack(alignment: stayLoggedIn ? .trailing : .leading) {
                        Capsule().fill(stayLoggedIn ? LimuColors.copper : LimuColors.divider)
                            .frame(width: 46, height: 26)
                        Circle().fill(LimuColors.white)
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                            .padding(2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stay logged in")
            }
            .padding(.vertical, 4)
            PrimaryButton(title: isLoading ? "Signing in…" : "Sign In", loading: isLoading) {
                isLoading = true
                Task {
                    let success = await appState.login(identifier: email, password: password, stayLoggedIn: stayLoggedIn)
                    isLoading = false
                    if success {
                        onLogin()
                    } else if appState.lastErrorCode == "ACCOUNT_CLAIM_REQUIRED" {
                        if await appState.requestAccountClaim(identifier: email) { mode = .claim }
                    } else if appState.lastErrorCode == "EMAIL_VERIFICATION_REQUIRED" {
                        verificationEmail = email
                        verificationPhone = ""
                        verificationIdentifier = email
                        verificationChannel = "whatsapp"
                        verificationLinkedAccount = false
                        verificationCode = ""
                        verificationResent = false
                        verificationCodeSent = false
                        appState.clearError()
                        mode = .verifyEmail
                        Task {
                            verificationCodeSent = await appState.resendRegistrationVerification(identifier: email, channel: "whatsapp")
                        }
                    }
                }
            }
            Text("Connected to the \(APIClient.environmentName) Limu V4 server")
                .font(.limu(size: 11))
                .foregroundStyle(LimuColors.muted)
                .frame(maxWidth: .infinity)
        }
    }

    private var registerStepTitles: [String] { ["Account", "Contact", "Password"] }

    private var isRegisterStepIncomplete: Bool {
        switch registerStep {
        case 0: return firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !isRegistrationPhoneValid || !email.contains("@") || location.isEmpty || (clientType == "Business" && businessName.isEmpty)
        default: return password != confirmPassword || !isRegistrationPasswordValid
        }
    }

    private var registerStepIndicator: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(registerStepTitles.indices, id: \.self) { index in
                    Capsule().fill(index <= registerStep ? LimuColors.copper : LimuColors.divider).frame(height: 4)
                }
            }
            Text("Step \(registerStep + 1) of \(registerStepTitles.count): \(registerStepTitles[registerStep])")
                .font(.limu(size: 11, weight: .medium))
                .foregroundStyle(LimuColors.secondary)
        }
    }

    private var registerForm: some View {
        VStack(spacing: 16) {
            registerStepIndicator
            switch registerStep {
            case 0:
                accountTypeSelector
                HStack(spacing: 12) {
                    LimuTextField(label: "First Name", placeholder: "Thandiwe", text: $firstName)
                    LimuTextField(label: "Last Name", placeholder: "Banda", text: $lastName)
                }
            case 1:
                CountryPhoneField(label: "Phone Number", text: $phone)
                LimuTextField(label: "Email Address", placeholder: "your@email.com", text: $email, keyboard: .emailAddress)
                DistrictPickerField(label: "District", selection: $location)
                if clientType == "Business" {
                    LimuTextField(label: "Business Name", placeholder: "Your business", text: $businessName)
                }
            default:
                LimuTextField(label: "Password", placeholder: "Create a strong password", text: $password, secure: true)
                passwordRequirements
                LimuTextField(label: "Confirm Password", placeholder: "Repeat password", text: $confirmPassword, secure: true)
                termsNotice
            }
            HStack(spacing: 10) {
                if registerStep > 0 {
                    Button("Back") { registerStep -= 1 }
                        .font(.limu(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "482A28"))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color(hex: "F5EEE6"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .buttonStyle(.plain)
                }
                if registerStep < registerStepTitles.count - 1 {
                    PrimaryButton(title: "Continue", disabled: isRegisterStepIncomplete) { registerStep += 1 }
                } else {
                    PrimaryButton(title: appState.isBusy ? "Creating Account…" : "Create Account", loading: appState.isBusy, disabled: isRegisterStepIncomplete) { submitRegistration() }
                }
            }
        }
    }

    private var termsNotice: some View {
        VStack(spacing: 2) {
            Text("By creating an account you agree to our")
            HStack(spacing: 4) {
                Link("Terms & Conditions", destination: LimuLinks.terms)
                Text("and")
                Link("Privacy Policy", destination: LimuLinks.privacyPolicy)
            }
        }
        .font(.limu(size: 11))
        .foregroundStyle(LimuColors.muted)
        .tint(LimuColors.copper)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func submitRegistration() {
        Task {
            if let registration = await appState.register(firstName: firstName, lastName: lastName, email: email, phone: phone, password: password, clientType: clientType, businessName: businessName, location: location) {
                let channel = (registration.channel ?? "whatsapp").lowercased()
                verificationChannel = ["whatsapp", "sms"].contains(channel) ? channel : "email"
                verificationEmail = registration.email
                verificationIdentifier = registration.identifier.flatMap { $0.isEmpty ? nil : $0 } ?? email
                verificationPhone = (registration.phone ?? "").isEmpty ? phone : (registration.phone ?? phone)
                verificationCode = ""
                verificationResent = false
                verificationLinkedAccount = registration.accountLinked ?? false
                verificationCodeSent = isWhatsAppChannel ? (registration.whatsappSent ?? registration.smsSent ?? true) : registration.emailSent
                mode = .verifyEmail
            }
        }
    }

    private var accountTypeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACCOUNT TYPE")
                .font(.limu(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(LimuColors.secondary)
            Text("Choose this first so we can show the right registration fields.")
                .font(.limu(size: 11, weight: .medium))
                .foregroundStyle(LimuColors.muted)
            HStack(spacing: 8) {
                ForEach(["Business", "Personal"], id: \.self) { type in
                    Button {
                        clientType = type
                    } label: {
                        Text(type)
                            .font(.limu(size: 13, weight: .semibold))
                            .foregroundStyle(clientType == type ? LimuColors.copper : LimuColors.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(clientType == type ? LimuColors.copperWash : LimuColors.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(clientType == type ? LimuColors.copper : LimuColors.charcoal.opacity(0.15), lineWidth: 1.5) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var verificationForm: some View {
        VStack(spacing: 18) {
            Image(systemName: isWhatsAppChannel ? "message.badge" : "envelope.badge")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(LimuColors.copper)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(isWhatsAppChannel ? "Check your WhatsApp" : "Check your inbox")
                    .font(.limu(size: 18, weight: .bold))
                    .foregroundStyle(LimuColors.ink)
                Text(verificationMessage)
                    .font(.limu(size: 13))
                    .foregroundStyle(LimuColors.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if verificationLinkedAccount {
                Label("We found your existing Limu account. Verifying links this app to it, so your cargo and order history comes with you.", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.limu(size: 11, weight: .medium))
                    .foregroundStyle(LimuColors.success)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LimuColors.successWash)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !verificationCodeSent {
                Label(
                    isWhatsAppChannel
                        ? "We couldn't send the WhatsApp code. Resend it, or use your email instead."
                        : "We couldn't send the email. Tap Resend code to try again.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                    .font(.limu(size: 11, weight: .medium))
                    .foregroundStyle(LimuColors.warning)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "FFFBEB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            LimuTextField(
                label: "6-Digit Verification Code",
                placeholder: "000000",
                text: $verificationCode,
                keyboard: .numberPad
            )
            .onChange(of: verificationCode) { _, value in
                let digits = value.filter(\.isNumber)
                verificationCode = String(digits.prefix(6))
            }

            PrimaryButton(
                title: appState.isBusy ? "Verifying…" : (isWhatsAppChannel ? "Verify Number" : "Verify Email"),
                loading: appState.isBusy,
                disabled: verificationCode.count != 6
            ) {
                Task {
                    let verified = isWhatsAppChannel
                        ? await appState.verifyRegistrationPhone(identifier: verificationIdentifier, code: verificationCode)
                        : await appState.verifyRegistrationEmail(identifier: verificationIdentifier, code: verificationCode)
                    if verified {
                        onLogin()
                    }
                }
            }

            VStack(spacing: 8) {
                Text("The code expires in 10 minutes.")
                    .font(.limu(size: 11))
                    .foregroundStyle(LimuColors.muted)
                Button(appState.isBusy ? "Sending…" : "Resend code") {
                    Task {
                        if await appState.resendRegistrationVerification(identifier: verificationIdentifier, channel: verificationChannel) {
                            verificationCode = ""
                            verificationResent = true
                            verificationCodeSent = true
                        }
                    }
                }
                .font(.limu(size: 13, weight: .semibold))
                .foregroundStyle(LimuColors.copper)
                .buttonStyle(.plain)
                .disabled(appState.isBusy)

                Button(isWhatsAppChannel ? "Can't get WhatsApp messages? Send the code to my email" : "Send the code to my WhatsApp instead") {
                    Task {
                        let newChannel = isWhatsAppChannel ? "email" : "whatsapp"
                        if await appState.resendRegistrationVerification(identifier: verificationIdentifier, channel: newChannel) {
                            verificationChannel = newChannel
                            verificationCode = ""
                            verificationResent = true
                            verificationCodeSent = true
                        }
                    }
                }
                .font(.limu(size: 12, weight: .semibold))
                .foregroundStyle(LimuColors.secondary)
                .buttonStyle(.plain)
                .disabled(appState.isBusy)

                if verificationResent {
                    Label("A new code has been sent", systemImage: "checkmark.circle.fill")
                        .font(.limu(size: 11, weight: .medium))
                        .foregroundStyle(LimuColors.success)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: verificationResent)
        }
        .frame(maxWidth: .infinity)
    }

    private var verificationMessage: String {
        if isWhatsAppChannel {
            if !verificationPhone.isEmpty {
                return "We sent a verification code to your WhatsApp on\n\(verificationPhone)"
            }
            return "We sent a verification code to the WhatsApp number on your account."
        }
        if verificationEmail.contains("@") {
            return "We sent a verification code to\n\(verificationEmail)"
        }
        return "We sent a verification code to the email address on your account."
    }

    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PASSWORD REQUIREMENTS")
                .font(.limu(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(LimuColors.secondary)

            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                passwordRequirement("6+ characters", isMet: password.count >= 6)
                passwordRequirement("1 uppercase", isMet: passwordHasUppercase)
                passwordRequirement("1 number", isMet: passwordHasNumber)
                passwordRequirement("1 special character", isMet: passwordHasSpecialCharacter)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isRegistrationPasswordValid ? LimuColors.successWash : LimuColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isRegistrationPasswordValid ? LimuColors.success.opacity(0.35) : LimuColors.divider, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.18), value: isRegistrationPasswordValid)
    }

    private func passwordRequirement(_ title: String, isMet: Bool) -> some View {
        Label {
            Text(title)
                .font(.limu(size: 11, weight: .medium))
                .foregroundStyle(isMet ? LimuColors.success : LimuColors.secondary)
        } icon: {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isMet ? LimuColors.success : LimuColors.muted)
        }
        .animation(.easeInOut(duration: 0.15), value: isMet)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(isMet ? "met" : "not met")")
    }

    private var forgotForm: some View {
        VStack(spacing: 16) {
            LimuTextField(label: "Email Address", placeholder: "your@email.com", text: $email, keyboard: .emailAddress)
            PrimaryButton(title: appState.isBusy ? "Sending…" : "Send Verification Code", loading: appState.isBusy) {
                Task {
                    if await appState.requestPasswordReset(identifier: email) {
                        resetIdentifier = email
                        resetCode = ""
                        resetResent = false
                        newPassword = ""
                        confirmNewPassword = ""
                        mode = .reset
                    }
                }
            }
        }
    }

    private var resetCodeForm: some View {
        VStack(spacing: 16) {
            Text(resetMessage)
                .font(.limu(size: 13))
                .foregroundStyle(LimuColors.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            LimuTextField(label: "6-Digit Verification Code", placeholder: "000000", text: $resetCode, keyboard: .numberPad)
                .onChange(of: resetCode) { _, value in
                    let digits = value.filter(\.isNumber)
                    resetCode = String(digits.prefix(6))
                }

            PrimaryButton(title: "Continue", disabled: resetCode.count != 6) {
                appState.clearError()
                mode = .resetPassword
            }

            VStack(spacing: 8) {
                Button(appState.isBusy ? "Sending…" : "Resend code") {
                    Task {
                        if await appState.requestPasswordReset(identifier: resetIdentifier) {
                            resetCode = ""
                            resetResent = true
                        }
                    }
                }
                .font(.limu(size: 13, weight: .semibold))
                .foregroundStyle(LimuColors.copper)
                .buttonStyle(.plain)
                .disabled(appState.isBusy)

                if resetResent {
                    Label("A new code has been sent", systemImage: "checkmark.circle.fill")
                        .font(.limu(size: 11, weight: .medium))
                        .foregroundStyle(LimuColors.success)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: resetResent)
        }
    }

    private var resetPasswordForm: some View {
        VStack(spacing: 16) {
            LimuTextField(label: "New Password", placeholder: "Minimum 8 characters", text: $newPassword, secure: true)
            newPasswordRequirements
            LimuTextField(label: "Confirm New Password", placeholder: "Repeat password", text: $confirmNewPassword, secure: true)
            PrimaryButton(title: appState.isBusy ? "Saving…" : "Change Password", loading: appState.isBusy, disabled: resetCode.count != 6 || !isNewPasswordValid || newPassword != confirmNewPassword) {
                Task {
                    if await appState.completePasswordReset(identifier: resetIdentifier, code: resetCode, password: newPassword) {
                        returnToSignIn()
                    } else {
                        // A rejected code is the likeliest failure: send the user back to re-enter it.
                        mode = .reset
                    }
                }
            }
        }
    }

    private var resetMessage: String {
        let sent = "We sent a verification code by email and WhatsApp (or text message)."
        if resetIdentifier.contains("@") {
            return "\(sent)\nCheck \(resetIdentifier) and your phone."
        }
        return "\(sent)\nCheck your email and your phone."
    }

    private var newPasswordRequirements: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEW PASSWORD NEEDS")
                .font(.limu(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(LimuColors.secondary)
            HStack(spacing: 12) {
                passwordRequirement("8+ characters", isMet: newPassword.count >= 8)
                passwordRequirement("1 letter", isMet: newPasswordHasLetter)
                passwordRequirement("1 number", isMet: newPasswordHasNumber)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isNewPasswordValid ? LimuColors.successWash : LimuColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isNewPasswordValid ? LimuColors.success.opacity(0.35) : LimuColors.divider, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.18), value: isNewPasswordValid)
    }

    private func returnToSignIn() {
        mode = .signIn
        registerStep = 0
        oneTimeToken = ""
        newPassword = ""
        confirmNewPassword = ""
        resetIdentifier = ""
        resetCode = ""
        resetResent = false
        password = ""
        appState.clearError()
    }

    private var claimForm: some View {
        VStack(spacing: 16) {
            Text("We found an existing Limu client record. Check your email or phone instructions, then enter the claim token below.")
                .font(.limu(size: 13))
                .foregroundStyle(LimuColors.secondary)
                .lineSpacing(3)
            LimuTextField(label: "Claim Token", placeholder: "Paste your claim token", text: $oneTimeToken)
            LimuTextField(label: "Create Password", placeholder: "Minimum 8 characters", text: $newPassword, secure: true)
            LimuTextField(label: "Confirm Password", placeholder: "Repeat password", text: $confirmNewPassword, secure: true)
            PrimaryButton(title: appState.isBusy ? "Claiming…" : "Claim Account", loading: appState.isBusy, disabled: oneTimeToken.isEmpty || newPassword.count < 8 || newPassword != confirmNewPassword) {
                Task {
                    if await appState.completeAccountClaim(token: oneTimeToken, password: newPassword) {
                        password = newPassword
                        mode = .signIn
                    }
                }
            }
        }
    }
}
