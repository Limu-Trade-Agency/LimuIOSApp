import SwiftUI

enum LimuColors {
    // Official Limu palette from the Corporate Identity Brand Guidelines.
    static let sunsetOrange = Color(hex: "FB7718")
    static let orange = Color(hex: "FD891D")
    static let yellow = Color(hex: "FFC628")
    static let limuGrey = Color(hex: "161A1C")
    static let darkRed = Color(hex: "150706")
    static let white = Color(hex: "FFFFFF")

    static let brandGradient = LinearGradient(
        colors: [sunsetOrange, orange, yellow],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Compatibility aliases keep feature views on the shared brand tokens.
    static let charcoal = limuGrey
    static let copper = sunsetOrange
    static let peach = yellow
    static let cream = Color(hex: "F5F6F6")
    static let softCream = Color(hex: "F7F8F8")
    static let ink = limuGrey
    static let secondary = Color(hex: "5E666A")
    static let muted = Color(hex: "899095")
    static let divider = Color(hex: "E1E4E5")
    static let copperWash = Color(hex: "FFF2E8")
    static let successWash = Color(hex: "ECFDF5")
    static let success = Color(hex: "15803D")
    static let warning = Color(hex: "B45309")
    static let dangerWash = Color(hex: "FEF2F2")
    static let danger = Color(hex: "B91C1C")
}

enum LimuLinks {
    /// Published privacy policy. The same URL is declared in App Store Connect —
    /// keep the two in sync, Apple rejects a listing whose policy link is dead.
    static let privacyPolicy = URL(string: "https://portal.limu.co.mw/policy")!
}

extension Font {
    static func limu(size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .ultraLight, .thin, .light:
            name = "Poppins-Light"
        case .medium:
            name = "Poppins-Medium"
        case .semibold:
            name = "Poppins-SemiBold"
        case .bold, .heavy, .black:
            name = "Poppins-Bold"
        default:
            name = "Poppins-Regular"
        }
        return .custom(name, size: size, relativeTo: .body)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 8:
            (a, r, g, b) = (value & 0xFF, value >> 24, value >> 16 & 0xFF, value >> 8 & 0xFF)
        default:
            (a, r, g, b) = (255, value >> 16, value >> 8 & 0xFF, value & 0xFF)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

enum AppTab: String, CaseIterable {
    case home = "Home"
    case cargo = "Cargo"
    case shipments = "Shipments"
    case orderForms = "Order Forms"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: "house"
        case .cargo: "shippingbox"
        case .shipments: "checklist"
        case .orderForms: "list.clipboard"
        case .profile: "person"
        }
    }

    var requiresCompletedKYC: Bool {
        false
    }
}

enum MalawiDistricts {
    static let all = [
        "Balaka", "Blantyre", "Chikwawa", "Chiradzulu", "Chitipa", "Dedza", "Dowa",
        "Karonga", "Kasungu", "Likoma", "Lilongwe", "Machinga", "Mangochi", "Mchinji",
        "Mulanje", "Mwanza", "Mzimba", "Neno", "Nkhata Bay", "Nkhotakota", "Nsanje",
        "Ntcheu", "Ntchisi", "Phalombe", "Rumphi", "Salima", "Thyolo", "Zomba"
    ]
}

enum LimuDateFormatting {
    static var defaultDateOfBirth: Date {
        makeDate(year: 1990, month: 1, day: 15)
    }

    static var dateOfBirthRange: ClosedRange<Date> {
        makeDate(year: 1900, month: 1, day: 1)...Date()
    }

    static func apiDate(from date: Date) -> String {
        apiFormatter().string(from: date)
    }

    static func date(fromAPI value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return apiFormatter().date(from: value)
    }

    static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func clamped(_ date: Date, to range: ClosedRange<Date>) -> Date {
        if date < range.lowerBound { return range.lowerBound }
        if date > range.upperBound { return range.upperBound }
        return date
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date()
    }

    private static func apiFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

struct PhoneCountryOption: Identifiable, Hashable {
    let isoCode: String
    let name: String
    let dialCode: String
    let minDigits: Int
    let maxDigits: Int
    let groups: [Int]
    var dropsTrunkPrefix = true

    var id: String { isoCode }
    var displayName: String { "\(name) \(dialCode)" }
    var lengthDescription: String {
        minDigits == maxDigits ? "\(maxDigits) digits" : "\(minDigits)–\(maxDigits) digits"
    }
    var placeholder: String {
        format(String(repeating: "0", count: maxDigits))
            .replacingOccurrences(of: "0", with: "•")
    }

    func nationalDigits(from value: String) -> String {
        var digits = value.filter(\.isNumber)
        let callingCode = dialCode.filter(\.isNumber)
        if digits.hasPrefix(callingCode) {
            digits.removeFirst(callingCode.count)
        }
        if dropsTrunkPrefix, digits.count > maxDigits, digits.hasPrefix("0") {
            digits.removeFirst()
        }
        return String(digits.prefix(maxDigits))
    }

    func format(_ digits: String) -> String {
        let clean = String(digits.filter(\.isNumber).prefix(maxDigits))
        guard !clean.isEmpty else { return "" }

        var remaining = clean[...]
        var parts: [String] = []
        for group in groups where !remaining.isEmpty {
            let end = remaining.index(remaining.startIndex, offsetBy: min(group, remaining.count))
            parts.append(String(remaining[..<end]))
            remaining = remaining[end...]
        }
        if !remaining.isEmpty {
            parts.append(String(remaining))
        }

        return parts.joined(separator: " ")
    }

    func isValid(_ digits: String) -> Bool {
        digits.count >= minDigits && digits.count <= maxDigits
    }
}

enum PhoneCountries {
    static let malawi = PhoneCountryOption(
        isoCode: "MW",
        name: "Malawi",
        dialCode: "+265",
        minDigits: 9,
        maxDigits: 9,
        groups: [3, 3, 3]
    )

    static let all: [PhoneCountryOption] = [
        malawi,
        PhoneCountryOption(isoCode: "ZM", name: "Zambia", dialCode: "+260", minDigits: 9, maxDigits: 9, groups: [2, 3, 4]),
        PhoneCountryOption(isoCode: "MZ", name: "Mozambique", dialCode: "+258", minDigits: 9, maxDigits: 9, groups: [2, 3, 4]),
        PhoneCountryOption(isoCode: "TZ", name: "Tanzania", dialCode: "+255", minDigits: 9, maxDigits: 9, groups: [3, 3, 3]),
        PhoneCountryOption(isoCode: "ZW", name: "Zimbabwe", dialCode: "+263", minDigits: 9, maxDigits: 9, groups: [2, 3, 4]),
        PhoneCountryOption(isoCode: "ZA", name: "South Africa", dialCode: "+27", minDigits: 9, maxDigits: 9, groups: [2, 3, 4]),
        PhoneCountryOption(isoCode: "BW", name: "Botswana", dialCode: "+267", minDigits: 7, maxDigits: 8, groups: [2, 3, 3]),
        PhoneCountryOption(isoCode: "NA", name: "Namibia", dialCode: "+264", minDigits: 9, maxDigits: 9, groups: [2, 3, 4]),
        PhoneCountryOption(isoCode: "KE", name: "Kenya", dialCode: "+254", minDigits: 9, maxDigits: 9, groups: [3, 3, 3]),
        PhoneCountryOption(isoCode: "UG", name: "Uganda", dialCode: "+256", minDigits: 9, maxDigits: 9, groups: [3, 3, 3]),
        PhoneCountryOption(isoCode: "RW", name: "Rwanda", dialCode: "+250", minDigits: 9, maxDigits: 9, groups: [3, 3, 3]),
        PhoneCountryOption(isoCode: "CD", name: "DR Congo", dialCode: "+243", minDigits: 9, maxDigits: 9, groups: [3, 3, 3]),
        PhoneCountryOption(isoCode: "NG", name: "Nigeria", dialCode: "+234", minDigits: 10, maxDigits: 10, groups: [3, 3, 4]),
        PhoneCountryOption(isoCode: "GH", name: "Ghana", dialCode: "+233", minDigits: 9, maxDigits: 9, groups: [2, 3, 4]),
        PhoneCountryOption(isoCode: "US", name: "United States", dialCode: "+1", minDigits: 10, maxDigits: 10, groups: [3, 3, 4], dropsTrunkPrefix: false),
        PhoneCountryOption(isoCode: "CA", name: "Canada", dialCode: "+1", minDigits: 10, maxDigits: 10, groups: [3, 3, 4], dropsTrunkPrefix: false),
        PhoneCountryOption(isoCode: "GB", name: "United Kingdom", dialCode: "+44", minDigits: 10, maxDigits: 10, groups: [4, 3, 3]),
        PhoneCountryOption(isoCode: "CN", name: "China", dialCode: "+86", minDigits: 11, maxDigits: 11, groups: [3, 4, 4]),
        PhoneCountryOption(isoCode: "IN", name: "India", dialCode: "+91", minDigits: 10, maxDigits: 10, groups: [5, 5]),
        PhoneCountryOption(isoCode: "AE", name: "United Arab Emirates", dialCode: "+971", minDigits: 9, maxDigits: 9, groups: [2, 3, 4])
    ]

    static func detect(_ value: String) -> PhoneCountryOption? {
        let digits = value.filter(\.isNumber)
        return all
            .sorted { $0.dialCode.count > $1.dialCode.count }
            .first { digits.hasPrefix($0.dialCode.filter(\.isNumber)) }
    }

    static func normalizedPhone(_ value: String, defaultCountry: PhoneCountryOption = malawi) -> String {
        let country = detect(value) ?? defaultCountry
        let digits = country.nationalDigits(from: value)
        guard !digits.isEmpty else { return "" }
        return "\(country.dialCode) \(country.format(digits))"
    }

    static func isValidPhone(_ value: String, defaultCountry: PhoneCountryOption = malawi) -> Bool {
        let country = detect(value) ?? defaultCountry
        return country.isValid(country.nationalDigits(from: value))
    }
}

struct BusinessCategoryOption: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

enum BusinessCategories {
    // Mobile-friendly labels adapted from the 21 ISIC Rev. 4 sections published by UNSD.
    static let all = [
        BusinessCategoryOption(code: "A", name: "Agriculture, Forestry & Fishing"),
        BusinessCategoryOption(code: "B", name: "Mining & Quarrying"),
        BusinessCategoryOption(code: "C", name: "Manufacturing"),
        BusinessCategoryOption(code: "D", name: "Electricity, Gas & Energy"),
        BusinessCategoryOption(code: "E", name: "Water, Waste & Environmental Services"),
        BusinessCategoryOption(code: "F", name: "Construction"),
        BusinessCategoryOption(code: "G", name: "Wholesale, Retail & Motor Trade"),
        BusinessCategoryOption(code: "H", name: "Transportation & Storage"),
        BusinessCategoryOption(code: "I", name: "Accommodation & Food Services"),
        BusinessCategoryOption(code: "J", name: "Information & Communication"),
        BusinessCategoryOption(code: "K", name: "Financial & Insurance Services"),
        BusinessCategoryOption(code: "L", name: "Real Estate"),
        BusinessCategoryOption(code: "M", name: "Professional, Scientific & Technical Services"),
        BusinessCategoryOption(code: "N", name: "Administrative & Support Services"),
        BusinessCategoryOption(code: "O", name: "Public Administration & Social Security"),
        BusinessCategoryOption(code: "P", name: "Education"),
        BusinessCategoryOption(code: "Q", name: "Health & Social Work"),
        BusinessCategoryOption(code: "R", name: "Arts, Entertainment & Recreation"),
        BusinessCategoryOption(code: "S", name: "Other Services"),
        BusinessCategoryOption(code: "T", name: "Household Employment & Own-use Production"),
        BusinessCategoryOption(code: "U", name: "International Organizations"),
        BusinessCategoryOption(code: "OTHER", name: "Other")
    ]
}

struct LimuEmblemMark: View {
    let size: CGFloat

    var body: some View {
        Image("LimuOrangeWatermark")
            .resizable()
            .scaledToFit()
            .padding(size * 0.05)
            .frame(width: size, height: size)
            .opacity(0.94)
            .accessibilityLabel("Limu Trade Agency")
    }
}

struct BrandDotPattern: View {
    var opacity: Double = 0.16

    var body: some View {
        Rectangle()
            .fill(LimuColors.brandGradient)
            .mask {
                Image("BrandDotPattern")
                    .resizable()
                    .scaledToFill()
                    .colorInvert()
                    .luminanceToAlpha()
            }
            .opacity(opacity)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

struct LimuOutlineLogoMark: View {
    var width: CGFloat = 128

    var body: some View {
        Image("LimuOutlineLogo")
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width)
            .accessibilityLabel("Limu Trade Agency")
    }
}

struct BrandHeaderBackdrop: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LimuColors.charcoal
            BrandDotPattern(opacity: 0.14)
                .frame(height: 88)
        }
        .ignoresSafeArea(edges: .top)
    }
}

struct BrandEmptyStateIcon: View {
    let systemName: String
    var symbolSize: CGFloat = 38

    var body: some View {
        BrandCircleSymbol(systemName: systemName, diameter: 108, symbolSize: symbolSize, patternOpacity: 0.32)
            .accessibilityHidden(true)
    }
}

struct BrandCircleSymbol: View {
    let systemName: String
    var diameter: CGFloat = 40
    var symbolSize: CGFloat = 17
    var patternOpacity: Double = 0.48

    var body: some View {
        ZStack {
            Image("BrandCirclePattern")
                .resizable()
                .scaledToFit()
                .frame(width: diameter, height: diameter)
                .opacity(patternOpacity)
                .blendMode(.multiply)
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(LimuColors.darkRed)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct AppHeader<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BrandHeaderBackdrop() }
        .foregroundStyle(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LimuColors.brandGradient).frame(height: 3)
        }
    }
}

struct BackHeader: View {
    let backTitle: String
    let title: String
    var subtitle: String?
    var status: String?
    let onBack: () -> Void

    var body: some View {
        AppHeader {
            Button(action: onBack) {
                Label(backTitle, systemImage: "chevron.left")
                    .font(.limu(size: 13, weight: .medium))
                    .foregroundStyle(LimuColors.peach)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.limu(size: 18, weight: .bold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.limu(size: 12))
                            .foregroundStyle(LimuColors.peach)
                    }
                }
                Spacer(minLength: 8)
                if let status {
                    StatusBadge(status: status)
                }
            }
        }
    }
}

struct LimuCard<Content: View>: View {
    var padding: CGFloat = 16
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LimuColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: LimuColors.charcoal.opacity(0.06), radius: 5, y: 2)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        LimuCard {
            Text(title.uppercased())
                .font(.limu(size: 11, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(LimuColors.muted)
                .padding(.bottom, 10)
            content
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.limu(size: 12))
                .foregroundStyle(LimuColors.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(monospaced ? .system(size: 12, weight: .semibold, design: .monospaced) : .limu(size: 12, weight: .semibold))
                .foregroundStyle(LimuColors.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LimuColors.softCream).frame(height: 1)
        }
        .padding(.bottom, 8)
    }
}

struct StatusBadge: View {
    let status: String
    var medium = false

    private var palette: (Color, Color, Color) {
        switch status {
        case "Active", "In Warehouse", "In Transit", "Upcoming", "Departed", "Draft":
            (Color(hex: "EFF6FF"), Color(hex: "1D4ED8"), Color(hex: "3B82F6"))
        case "Ready for Collection", "Paid", "Approved", "Completed", "Purchased", "Item Approved":
            (LimuColors.successWash, LimuColors.success, Color(hex: "22C55E"))
        case "Loading":
            (Color(hex: "FFF7ED"), Color(hex: "C2410C"), Color(hex: "F97316"))
        case "Payment Pending", "Partially Paid", "Pending", "Pending Payment", "Pending Purchase":
            (Color(hex: "FFFBEB"), LimuColors.warning, Color(hex: "F59E0B"))
        case "Not Paid", "Declined", "Not Started", "Dormant", "Item Declined":
            (LimuColors.dangerWash, LimuColors.danger, Color(hex: "EF4444"))
        case "Pending Review", "Client Review", "Supervisor Review":
            (Color(hex: "F5F3FF"), Color(hex: "6D28D9"), Color(hex: "8B5CF6"))
        default:
            (Color(hex: "F3F4F6"), Color(hex: "4B5563"), LimuColors.muted)
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(palette.2).frame(width: 6, height: 6)
            Text(status)
                .font(.limu(size: medium ? 11 : 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(palette.1)
        .padding(.horizontal, medium ? 10 : 8)
        .padding(.vertical, medium ? 5 : 6)
        .background(palette.0)
        .clipShape(Capsule())
    }
}

struct IconText: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.limu(size: 10, weight: .medium))
                .foregroundStyle(LimuColors.copper)
            Text(text)
                .font(.limu(size: 11))
                .foregroundStyle(LimuColors.secondary)
                .lineLimit(2)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var loading = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(LimuColors.darkRed).controlSize(.small) }
                Text(title)
                    .font(.limu(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(LimuColors.darkRed)
            .background(LimuColors.brandGradient.opacity(disabled ? 0.48 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled || loading)
    }
}

struct LimuTextField: View {
    let label: String
    var placeholder = ""
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.limu(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(LimuColors.secondary)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                }
            }
            .font(.limu(size: 14))
            .foregroundStyle(LimuColors.ink)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(LimuColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5)
            }
        }
    }
}

struct DatePickerField: View {
    let label: String
    @Binding var date: Date
    var range: ClosedRange<Date> = LimuDateFormatting.dateOfBirthRange

    @State private var draftDate = LimuDateFormatting.defaultDateOfBirth
    @State private var isPresented = false

    private var displayValue: String {
        LimuDateFormatting.displayDate(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.limu(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(LimuColors.secondary)
            Button {
                draftDate = LimuDateFormatting.clamped(date, to: range)
                isPresented = true
            } label: {
                HStack(spacing: 10) {
                    Text(displayValue)
                        .font(.limu(size: 14))
                        .foregroundStyle(LimuColors.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LimuColors.copper)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(LimuColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(displayValue)
        }
        .onAppear {
            date = LimuDateFormatting.clamped(date, to: range)
        }
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose your date of birth")
                            .font(.limu(size: 16, weight: .bold))
                            .foregroundStyle(LimuColors.ink)
                        Text("This will be saved as \(LimuDateFormatting.apiDate(from: draftDate)).")
                            .font(.limu(size: 12, weight: .medium))
                            .foregroundStyle(LimuColors.muted)
                    }

                    DatePicker(
                        label,
                        selection: $draftDate,
                        in: range,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 238)
                    .padding(.vertical, 8)
                    .background(LimuColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LimuColors.charcoal.opacity(0.08), lineWidth: 1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LimuColors.cream)
                .navigationTitle(label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            date = LimuDateFormatting.clamped(draftDate, to: range)
                            isPresented = false
                        }
                        .font(.limu(size: 14, weight: .semibold))
                    }
                }
            }
            .tint(LimuColors.copper)
            .preferredColorScheme(.light)
        }
    }
}

struct CountryPhoneField: View {
    let label: String
    @Binding var text: String
    @State private var selectedCountry = PhoneCountries.malawi
    @State private var nationalDigits = ""
    @State private var displayedNumber = ""
    @State private var isPresented = false

    private var isComplete: Bool {
        nationalDigits.isEmpty || selectedCountry.isValid(nationalDigits)
    }

    private var helperText: String {
        if nationalDigits.isEmpty {
            return "Choose a country code and enter a \(selectedCountry.lengthDescription) number."
        }
        if selectedCountry.isValid(nationalDigits) {
            return "Phone will be saved as \(selectedCountry.dialCode) \(selectedCountry.format(nationalDigits))."
        }
        return "\(selectedCountry.name) numbers require \(selectedCountry.lengthDescription)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.limu(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(LimuColors.secondary)

            HStack(spacing: 8) {
                Button { isPresented = true } label: {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(selectedCountry.isoCode)
                                .font(.limu(size: 10, weight: .bold))
                                .foregroundStyle(LimuColors.muted)
                            Text(selectedCountry.dialCode)
                                .font(.limu(size: 13, weight: .semibold))
                                .foregroundStyle(LimuColors.ink)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(LimuColors.muted)
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 102, height: 46)
                    .background(LimuColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Country code")
                .accessibilityValue(selectedCountry.displayName)

                FormattedPhoneNumberTextField(
                    placeholder: selectedCountry.placeholder,
                    text: $displayedNumber,
                    country: selectedCountry
                ) { digits in
                    nationalDigits = digits
                    writeFormattedPhone()
                }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(LimuColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isComplete ? LimuColors.charcoal.opacity(0.15) : LimuColors.warning.opacity(0.65), lineWidth: 1.5)
                    }
            }

            Label(helperText, systemImage: isComplete ? "info.circle" : "exclamationmark.triangle.fill")
                .font(.limu(size: 11, weight: .medium))
                .foregroundStyle(isComplete ? LimuColors.muted : LimuColors.warning)
        }
        .onAppear { syncFromText(text) }
        .onChange(of: text) { _, value in syncFromText(value) }
        .onChange(of: selectedCountry) { _, country in
            nationalDigits = country.nationalDigits(from: nationalDigits)
            displayedNumber = country.format(nationalDigits)
            writeFormattedPhone()
        }
        .sheet(isPresented: $isPresented) {
            CountryCodePicker(selection: $selectedCountry, isPresented: $isPresented)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.light)
        }
    }

    private func syncFromText(_ value: String) {
        let valueDigits = value.filter(\.isNumber)
        let selectedCallingCode = selectedCountry.dialCode.filter(\.isNumber)
        let keepsCurrentCountry = !selectedCallingCode.isEmpty && valueDigits.hasPrefix(selectedCallingCode)

        if let detectedCountry = PhoneCountries.detect(value),
           !keepsCurrentCountry,
           detectedCountry != selectedCountry {
            selectedCountry = detectedCountry
        }
        let country = keepsCurrentCountry ? selectedCountry : (PhoneCountries.detect(value) ?? selectedCountry)
        let digits = country.nationalDigits(from: value)
        if nationalDigits != digits {
            nationalDigits = digits
        }
        let formatted = country.format(digits)
        if displayedNumber != formatted {
            displayedNumber = formatted
        }
    }

    private func writeFormattedPhone() {
        let formatted = nationalDigits.isEmpty ? "" : "\(selectedCountry.dialCode) \(selectedCountry.format(nationalDigits))"
        if text != formatted {
            text = formatted
        }
    }
}

private struct FormattedPhoneNumberTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let country: PhoneCountryOption
    let onDigitsChange: (String) -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.keyboardType = .phonePad
        textField.textContentType = .telephoneNumber
        textField.autocorrectionType = .no
        textField.tintColor = UIColor(red: 0.98, green: 0.47, blue: 0.09, alpha: 1)
        textField.textColor = UIColor(red: 0.09, green: 0.10, blue: 0.11, alpha: 1)
        textField.font = UIFont(name: "Poppins-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        if textField.text != text {
            textField.text = text
        }
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(red: 0.54, green: 0.56, blue: 0.58, alpha: 0.55),
                .font: UIFont(name: "Poppins-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
            ]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: FormattedPhoneNumberTextField

        init(parent: FormattedPhoneNumberTextField) {
            self.parent = parent
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""
            guard let textRange = Range(range, in: current) else { return false }

            let proposed = current.replacingCharacters(in: textRange, with: string)
            let digits = parent.country.nationalDigits(from: proposed)
            let formatted = parent.country.format(digits)
            textField.text = formatted

            DispatchQueue.main.async {
                self.parent.text = formatted
                self.parent.onDigitsChange(digits)
            }

            return false
        }
    }
}

private struct CountryCodePicker: View {
    @Binding var selection: PhoneCountryOption
    @Binding var isPresented: Bool
    @State private var search = ""

    private var countries: [PhoneCountryOption] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return PhoneCountries.all }
        return PhoneCountries.all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.isoCode.localizedCaseInsensitiveContains(query)
                || $0.dialCode.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(countries) { country in
                        Button {
                            selection = country
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                Text(country.isoCode)
                                    .font(.limu(size: 11, weight: .bold))
                                    .foregroundStyle(LimuColors.copper)
                                    .frame(width: 34, height: 34)
                                    .background(LimuColors.copperWash)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(country.name)
                                        .font(.limu(size: 14, weight: selection == country ? .semibold : .regular))
                                        .foregroundStyle(LimuColors.ink)
                                    Text("\(country.dialCode) • \(country.lengthDescription)")
                                        .font(.limu(size: 11, weight: .medium))
                                        .foregroundStyle(LimuColors.muted)
                                }

                                Spacer(minLength: 8)

                                if selection == country {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(LimuColors.copper)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .frame(minHeight: 54)
                            .background(selection == country ? LimuColors.copperWash : LimuColors.white)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(LimuColors.divider).frame(height: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(LimuColors.cream)
            .navigationTitle("Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search country or code")
            .overlay {
                if countries.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .tint(LimuColors.copper)
    }
}

struct DistrictPickerField: View {
    let label: String
    @Binding var selection: String
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.limu(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(LimuColors.secondary)
            Button { isPresented = true } label: {
                HStack {
                    Text(selection.isEmpty ? "Select a district" : selection)
                        .font(.limu(size: 14))
                        .foregroundStyle(selection.isEmpty ? LimuColors.muted : LimuColors.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LimuColors.muted)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(LimuColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(selection.isEmpty ? "No district selected" : selection)
        }
        .sheet(isPresented: $isPresented) {
            MalawiDistrictPicker(selection: $selection, isPresented: $isPresented)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.light)
        }
    }
}

private struct MalawiDistrictPicker: View {
    @Binding var selection: String
    @Binding var isPresented: Bool
    @State private var search = ""

    private var districts: [String] {
        search.isEmpty
            ? MalawiDistricts.all
            : MalawiDistricts.all.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(districts, id: \.self) { district in
                        Button {
                            selection = district
                            isPresented = false
                        } label: {
                            HStack {
                                Text(district)
                                    .font(.limu(size: 14, weight: selection == district ? .semibold : .regular))
                                    .foregroundStyle(LimuColors.ink)
                                Spacer()
                                if selection == district {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(LimuColors.copper)
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 48)
                            .background(selection == district ? LimuColors.copperWash : LimuColors.white)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(LimuColors.divider).frame(height: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(LimuColors.cream)
            .navigationTitle("Select District")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search districts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .tint(LimuColors.copper)
    }
}

struct BusinessCategoryPickerField: View {
    let label: String
    @Binding var selection: String
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.limu(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(LimuColors.secondary)
            Button { isPresented = true } label: {
                HStack(spacing: 10) {
                    Text(selection.isEmpty ? "Select a business category" : selection)
                        .font(.limu(size: 14))
                        .foregroundStyle(selection.isEmpty ? LimuColors.muted : LimuColors.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LimuColors.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(minHeight: 46)
                .background(LimuColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(selection.isEmpty ? "No business category selected" : selection)
        }
        .sheet(isPresented: $isPresented) {
            BusinessCategoryPicker(selection: $selection, isPresented: $isPresented)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.light)
        }
    }
}

private struct BusinessCategoryPicker: View {
    @Binding var selection: String
    @Binding var isPresented: Bool
    @State private var search = ""

    private var categories: [BusinessCategoryOption] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return BusinessCategories.all }
        return BusinessCategories.all.filter {
            $0.code.localizedCaseInsensitiveContains(query) || $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(categories) { category in
                        Button {
                            selection = category.name
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                Text(category.code == "OTHER" ? "—" : category.code)
                                    .font(.limu(size: 11, weight: .bold))
                                    .foregroundStyle(LimuColors.copper)
                                    .frame(width: 30, height: 30)
                                    .background(LimuColors.copperWash)
                                    .clipShape(Circle())
                                Text(category.name)
                                    .font(.limu(size: 14, weight: selection == category.name ? .semibold : .regular))
                                    .foregroundStyle(LimuColors.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                if selection == category.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(LimuColors.copper)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .frame(minHeight: 52)
                            .background(selection == category.name ? LimuColors.copperWash : LimuColors.white)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(LimuColors.divider).frame(height: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(LimuColors.cream)
            .navigationTitle("Business Category")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search business categories")
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .tint(LimuColors.copper)
    }
}

struct FilterStrip: View {
    let items: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    Button {
                        selection = item
                    } label: {
                        Text(item)
                            .font(.limu(size: 12, weight: .semibold))
                            .foregroundStyle(selection == item ? LimuColors.copper : LimuColors.muted)
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(selection == item ? LimuColors.copper : .clear)
                                    .frame(height: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(LimuColors.white)
        .overlay(alignment: .bottom) { Rectangle().fill(LimuColors.charcoal.opacity(0.1)).frame(height: 1) }
    }
}

struct SegmentedTabs: View {
    let items: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    Text(item)
                        .font(.limu(size: 12, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(selection == item ? LimuColors.copper : LimuColors.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(selection == item ? LimuColors.copper : .clear).frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .background(LimuColors.white)
        .overlay(alignment: .bottom) { Rectangle().fill(LimuColors.charcoal.opacity(0.1)).frame(height: 1) }
    }
}

// MARK: - Visual-refresh primitives (Home / Cargo / Shipments / Order Forms / Notifications only —
// Profile and KYC intentionally keep the plain LimuCard/BrandCircleSymbol look above, so none of
// the existing components in this file are modified; these are purely additive). Ported from the
// Android app's design/Components.kt (AccentCard/GradientIconTile/SectionAccentBar/
// statusAccentColor) — Android picked these up in a design-system pass this file didn't get, so
// this closes that parity gap rather than introducing a new one. NOT verified by a build in the
// environment this was ported from (no Xcode/Swift toolchain available) — sanity-check in Xcode
// before shipping.

/// Same status→color mapping `StatusBadge` uses internally (its third tuple element), exposed as a
/// free function so cards outside `StatusBadge` can accent themselves by status too.
func statusAccentColor(_ status: String) -> Color {
    switch status {
    case "Active", "In Warehouse", "In Transit", "Upcoming", "Departed", "Draft":
        return Color(hex: "3B82F6")
    case "Ready for Collection", "Paid", "Approved", "Completed", "Purchased", "Item Approved":
        return Color(hex: "22C55E")
    case "Loading":
        return Color(hex: "F97316")
    case "Payment Pending", "Partially Paid", "Pending", "Pending Payment", "Pending Purchase":
        return Color(hex: "F59E0B")
    case "Not Paid", "Declined", "Not Started", "Dormant", "Item Declined":
        return Color(hex: "EF4444")
    case "Pending Review", "Client Review", "Supervisor Review":
        return Color(hex: "8B5CF6")
    default:
        return LimuColors.muted
    }
}

/// A richer alternative to `LimuCard`: same white/rounded body, but with a soft colour-tinted
/// shadow and a thin gradient accent bar along the top edge. Intended for list/preview cards on
/// the redesigned screens; `LimuCard` itself is untouched so Profile/KYC keep their current look.
struct AccentCard<Content: View>: View {
    let accentColor: Color
    var padding: CGFloat = 16
    let content: Content

    init(accentColor: Color, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.accentColor = accentColor
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LinearGradient(colors: [accentColor, accentColor.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 3.5)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(padding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LimuColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Android pairs an 8dp-elevation ambient shadow with a colour-tinted spot shadow; SwiftUI
        // has no ambient/spot split, so two stacked .shadow modifiers approximate it.
        .shadow(color: LimuColors.charcoal.opacity(0.07), radius: 8, y: 3)
        .shadow(color: accentColor.opacity(0.22), radius: 8, y: 3)
    }
}

/// A diagonal-gradient rounded icon tile — a more vivid stand-in for `BrandCircleSymbol` on the
/// redesigned screens (Home metrics, notification categories).
struct GradientIconTile: View {
    let systemName: String
    let colors: [Color]
    var diameter: CGFloat = 40
    var symbolSize: CGFloat = 18

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(RoundedRectangle(cornerRadius: diameter / 3, style: .continuous))
    }
}

/// Small gradient dash used ahead of a section title for a bit of colour on the redesigned screens.
struct SectionAccentBar: View {
    var color: Color = LimuColors.copper

    var body: some View {
        LinearGradient(colors: [color, color.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            .frame(width: 4, height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }
}
