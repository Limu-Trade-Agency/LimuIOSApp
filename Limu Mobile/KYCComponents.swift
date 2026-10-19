import SwiftUI

// Selection controls for the KYC and profile forms. Every choice comes from the shared KYC options
// the API serves, so people pick from the same accepted values the portal offers instead of typing
// free text that then has to be reconciled.

private func kycFieldLabel(_ title: String) -> some View {
    Text(title.uppercased())
        .font(.limu(size: 12, weight: .semibold))
        .tracking(0.6)
        .foregroundStyle(LimuColors.secondary)
}

private struct KYCFieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
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
}

extension View {
    fileprivate func kycFieldChrome() -> some View { modifier(KYCFieldChrome()) }
}

/// Wraps its children onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Pick one value from a searchable list (business category, occupation, ...).
struct OptionPickerField: View {
    let label: String
    var placeholder = "Select"
    let options: [String]
    @Binding var selection: String
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            kycFieldLabel(label)
            Button { isPresented = true } label: {
                HStack(spacing: 10) {
                    Text(selection.isEmpty ? placeholder : selection)
                        .font(.limu(size: 14))
                        .foregroundStyle(selection.isEmpty ? LimuColors.muted : LimuColors.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LimuColors.muted)
                }
                .kycFieldChrome()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(selection.isEmpty ? "Nothing selected" : selection)
        }
        .sheet(isPresented: $isPresented) {
            OptionPickerSheet(title: label, options: options, selection: $selection, isPresented: $isPresented)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.light)
        }
    }
}

private struct OptionPickerSheet: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    @Binding var isPresented: Bool
    @State private var search = ""

    /// A value saved before the shared list existed stays selectable until the person chooses another.
    private var all: [String] {
        selection.isEmpty || options.contains(selection) ? options : [selection] + options
    }

    private var visible: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visible, id: \.self) { option in
                        Button {
                            selection = option
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                Text(option)
                                    .font(.limu(size: 14, weight: selection == option ? .semibold : .regular))
                                    .foregroundStyle(LimuColors.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                if selection == option {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LimuColors.copper)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .frame(minHeight: 50)
                            .background(selection == option ? LimuColors.copperWash : LimuColors.white)
                            .overlay(alignment: .bottom) { Rectangle().fill(LimuColors.divider).frame(height: 1) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(LimuColors.cream)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search")
            .overlay {
                if visible.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
            }
        }
        .tint(LimuColors.copper)
    }
}

/// Pick any number of values from a searchable list; the picks show as removable chips.
struct MultiSelectField: View {
    let label: String
    var hint: String?
    var placeholder = "Select"
    let options: [String]
    @Binding var selection: [String]
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            kycFieldLabel(label)
            if let hint {
                Text(hint).font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
            }
            Button { isPresented = true } label: {
                HStack(spacing: 10) {
                    Text(selection.isEmpty ? placeholder : "\(selection.count) selected")
                        .font(.limu(size: 14))
                        .foregroundStyle(selection.isEmpty ? LimuColors.muted : LimuColors.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LimuColors.copper)
                }
                .kycFieldChrome()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(selection.isEmpty ? "Nothing selected" : selection.joined(separator: ", "))

            if !selection.isEmpty {
                FlowLayout {
                    ForEach(selection, id: \.self) { item in
                        Button { selection.removeAll { $0 == item } } label: {
                            HStack(spacing: 6) {
                                Text(item)
                                Image(systemName: "xmark").font(.limu(size: 9, weight: .bold))
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
                        .accessibilityLabel("Remove \(item)")
                    }
                }
                .padding(.top, 2)
            }
        }
        .sheet(isPresented: $isPresented) {
            MultiSelectSheet(title: label, options: options, selection: $selection, isPresented: $isPresented)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.light)
        }
    }
}

private struct MultiSelectSheet: View {
    let title: String
    let options: [String]
    @Binding var selection: [String]
    @Binding var isPresented: Bool
    @State private var search = ""

    /// Values saved before the shared list existed stay listed (and removable) at the top.
    private var all: [String] {
        selection.filter { !options.contains($0) } + options
    }

    private var visible: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visible, id: \.self) { option in
                        let isSelected = selection.contains(option)
                        Button {
                            if isSelected { selection.removeAll { $0 == option } } else { selection.append(option) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.limu(size: 18, weight: .semibold))
                                    .foregroundStyle(isSelected ? LimuColors.copper : LimuColors.muted)
                                Text(option)
                                    .font(.limu(size: 14, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(LimuColors.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .frame(minHeight: 50)
                            .background(isSelected ? LimuColors.copperWash : LimuColors.white)
                            .overlay(alignment: .bottom) { Rectangle().fill(LimuColors.divider).frame(height: 1) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 8)
            }
            .background(LimuColors.cream)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search")
            .overlay {
                if visible.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }.font(.limu(size: 14, weight: .semibold))
                }
            }
        }
        .tint(LimuColors.copper)
    }
}

/// A short set of mutually exclusive choices shown as side-by-side tiles (gender, import/export, ...).
struct ChoiceTiles: View {
    var label: String?
    let options: [String]
    var icons: [String: String] = [:]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label { kycFieldLabel(label) }
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.caseInsensitiveCompare(option) == .orderedSame
                    Button { selection = option } label: {
                        VStack(spacing: 6) {
                            if let icon = icons[option] {
                                Image(systemName: icon).font(.limu(size: 16, weight: .bold))
                            }
                            Text(option)
                                .font(.limu(size: 12, weight: .bold))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(isSelected ? .white : LimuColors.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: icons.isEmpty ? 46 : 62)
                        .background(isSelected ? LimuColors.copper : LimuColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? LimuColors.copper : LimuColors.charcoal.opacity(0.14), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

/// Longer single-choice list (business size), one option per row.
struct ChoiceList: View {
    let label: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            kycFieldLabel(label)
            VStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection == option
                    Button { selection = option } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .font(.limu(size: 18, weight: .semibold))
                                .foregroundStyle(isSelected ? LimuColors.copper : LimuColors.muted)
                            Text(option)
                                .font(.limu(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(LimuColors.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(isSelected ? LimuColors.copperWash : LimuColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSelected ? LimuColors.copper : LimuColors.charcoal.opacity(0.15), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

/// A value that comes from the verified account (phone, email) and cannot be edited here.
struct ReadOnlyField: View {
    let label: String
    let value: String
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            kycFieldLabel(label)
            HStack(spacing: 8) {
                Text(value.isEmpty ? "—" : value)
                    .font(.limu(size: 14))
                    .foregroundStyle(LimuColors.secondary)
                Spacer(minLength: 8)
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LimuColors.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minHeight: 46)
            .background(LimuColors.softCream)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(LimuColors.charcoal.opacity(0.08), lineWidth: 1)
            }
            if let note {
                Text(note).font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
