import SwiftUI
import UniformTypeIdentifiers

private extension Invoice {
    var isShipping: Bool { !isCustoms && typeLabel.caseInsensitiveCompare("Shipping") == .orderedSame }
    var displayTitle: String {
        typeLabel != "Order Form" && !shipmentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && shipmentID != "—" ? shipmentID : id
    }
}

struct InvoicesView: View {
    @EnvironmentObject private var appState: AppState
    private enum Screen { case list, detail, upload }

    @State private var screen: Screen = .list
    @State private var filter = "All"
    @State private var selectedInvoice: Invoice?
    private let filters = ["All", "Not Paid", "Partially Paid", "Paid"]

    private var filtered: [Invoice] { appState.invoices.filter { filter == "All" || $0.status == filter } }
    private var outstanding: String {
        let balances = Dictionary(grouping: appState.invoices.filter { $0.status != "Paid" }, by: \.currency)
        guard !balances.isEmpty else { return "—" }
        return balances.keys.sorted().map { currency in
            MockData.money(balances[currency, default: []].reduce(0) { $0 + $1.balance }, currency: currency)
        }.joined(separator: " · ")
    }

    var body: some View {
        Group {
            switch screen {
            case .list: listView
            case .detail:
                if let selectedInvoice {
                    InvoiceDetailView(invoice: selectedInvoice, onBack: backToList, onUpload: { screen = .upload }, onProofAdded: reloadSelected)
                }
            case .upload:
                if let selectedInvoice { PaymentUploadView(invoice: selectedInvoice, onBack: backToDetail) }
            }
        }
        .task(id: appState.pendingLink) { await openPendingLink() }
    }

    /// Returning to the list reloads it, so a payment that was just reviewed or a new invoice shows up
    /// without leaving the tab and coming back.
    private func backToList() {
        screen = .list
        Task { await appState.refreshInvoices() }
    }

    /// After uploading proof the invoice is fetched again, so its balance and payment history are current.
    private func backToDetail() {
        screen = .detail
        guard let current = selectedInvoice else { return }
        Task {
            await appState.refreshInvoices()
            if let fresh = try? await appState.fetchInvoiceDetail(current.apiID) { selectedInvoice = fresh }
        }
    }

    private func reloadSelected() {
        guard let current = selectedInvoice else { return }
        Task {
            if let fresh = try? await appState.fetchInvoiceDetail(current.apiID) { selectedInvoice = fresh }
        }
    }

    /// A tapped invoice notification names one invoice: open it directly, not just the list.
    private func openPendingLink() async {
        guard case .invoice(let id)? = appState.pendingLink else { return }
        defer {
            if appState.pendingLink == .invoice(id) { appState.pendingLink = nil }
        }
        do {
            selectedInvoice = try await appState.fetchInvoiceDetail(id)
            screen = .detail
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            AppHeader {
                Text("Invoices")
                    .font(.limu(size: 18, weight: .bold))
                HStack(spacing: 3) {
                    Text("Total Outstanding:")
                    Text(outstanding).fontWeight(.bold).foregroundStyle(LimuColors.copper)
                }
                .font(.limu(size: 12))
                .foregroundStyle(LimuColors.secondary)
                .padding(.top, 2)
            }
            FilterStrip(items: filters, selection: $filter)
            ScrollView {
                LazyVStack(spacing: 10) {
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            BrandEmptyStateIcon(systemName: "doc.text.magnifyingglass")
                            Text("No invoices in this group")
                                .font(.limu(size: 14, weight: .semibold))
                                .foregroundStyle(LimuColors.muted)
                        }
                        .padding(.top, 40)
                    }
                    ForEach(filtered) { invoice in
                        Button {
                            selectedInvoice = invoice
                            screen = .detail
                            Task {
                                do { selectedInvoice = try await appState.fetchInvoiceDetail(invoice.apiID) }
                                catch { appState.errorMessage = error.localizedDescription }
                            }
                        } label: {
                            invoiceCard(invoice)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .background(LimuColors.pageBackground)
        .task { await appState.refreshInvoices() }
    }

    private func invoiceCard(_ invoice: Invoice) -> some View {
        LimuCard(padding: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(invoice.displayTitle).font(.limu(size: 14, weight: .bold)).foregroundStyle(LimuColors.ink)
                    if invoice.isShipping {
                        Text("Global Access Trade").font(.limu(size: 11, weight: .semibold)).foregroundStyle(LimuColors.copper)
                    }
                    Text([invoice.typeLabel, invoice.displayTitle == invoice.id ? nil : invoice.id, invoice.date, invoice.currency].compactMap { $0 }.joined(separator: " · "))
                        .font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                }
                Spacer()
                StatusBadge(status: invoice.status)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total").font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                    Text(MockData.money(invoice.total, currency: invoice.currency)).font(.limu(size: 13, weight: .bold)).foregroundStyle(Color(hex: "374151"))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Balance Due").font(.limu(size: 11)).foregroundStyle(LimuColors.muted)
                    Text(MockData.money(invoice.balance, currency: invoice.currency))
                        .font(.limu(size: 16, weight: .heavy))
                        .foregroundStyle(invoice.balance > 0 ? LimuColors.danger : LimuColors.success)
                }
            }
            .padding(.top, 10)
            if invoice.status == "Not Paid" {
                Label("Action required — Upload payment proof", systemImage: "exclamationmark.triangle.fill")
                    .font(.limu(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "482A28"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LimuColors.copperWash)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(LimuColors.peach) }
                    .padding(.top, 10)
            }
        }
    }
}

private struct InvoiceDetailView: View {
    @EnvironmentObject private var appState: AppState
    let invoice: Invoice
    let onBack: () -> Void
    let onUpload: () -> Void
    let onProofAdded: () -> Void
    /// The payment getting another proof (30 Oct 2026: replacing is withdrawn); applies to every invoice type.
    @State private var addingProofPaymentID: Int?
    @State private var showingAddProofImporter = false

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: "Invoices", title: invoice.displayTitle, subtitle: "\(invoice.typeLabel) · \(invoice.date)", status: invoice.status, onBack: onBack)
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.balance > 0 ? "AMOUNT DUE" : "FULLY PAID")
                            .font(.limu(size: 11, weight: .bold)).tracking(0.6)
                            .foregroundStyle(invoice.balance > 0 ? Color(hex: "482A28") : LimuColors.success)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(MockData.money(invoice.balance, currency: invoice.currency))
                                .font(.limu(size: 28, weight: .heavy))
                        }
                        .foregroundStyle(invoice.balance > 0 ? LimuColors.copper : LimuColors.success)
                        Text("Invoice Total: \(MockData.money(invoice.total, currency: invoice.currency))")
                            .font(.limu(size: 12)).foregroundStyle(LimuColors.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(invoice.balance > 0 ? LimuColors.copperWash : LimuColors.successWash)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(invoice.balance > 0 ? LimuColors.peach : Color(hex: "86EFAC")) }

                    SectionCard("Line Items") {
                        ForEach(Array(invoice.items.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label)
                                        .font(.limu(size: 13, weight: item.total < 0 ? .semibold : .regular))
                                        .foregroundStyle(LimuColors.ink)
                                    if item.quantity > 1 { Text("× \(item.quantity)").font(.limu(size: 11)).foregroundStyle(LimuColors.muted) }
                                }
                                Spacer()
                                Text(MockData.money(item.total, currency: invoice.currency))
                                    .font(.limu(size: 13, weight: .bold))
                                    .foregroundStyle(item.total < 0 ? LimuColors.success : LimuColors.ink)
                            }
                            .padding(.bottom, 10)
                            if index < invoice.items.count - 1 { Rectangle().fill(LimuColors.softCream).frame(height: 1).padding(.bottom, 10) }
                        }
                        HStack {
                            Text("Total").font(.limu(size: 14, weight: .bold))
                            Spacer()
                            Text(MockData.money(invoice.total, currency: invoice.currency)).font(.limu(size: 14, weight: .heavy))
                        }
                        .foregroundStyle(LimuColors.ink)
                        .padding(.top, 12)
                        .overlay(alignment: .top) { Rectangle().fill(LimuColors.charcoal.opacity(0.1)).frame(height: 2) }
                    }

                    SectionCard("Details") {
                        if invoice.isShipping { DetailRow(label: "Issued by", value: "Global Access Trade") }
                        DetailRow(label: "Invoice Type", value: invoice.typeLabel)
                        DetailRow(label: "Invoice Number", value: invoice.id)
                        if let orderFormNumber = invoice.orderFormNumber {
                            DetailRow(label: "Order Form", value: orderFormNumber)
                        }
                        // A customs clearance invoice belongs to the shipment, so it carries no cargo or bus number.
                        if !invoice.isCustoms, invoice.cargoID != "—" { DetailRow(label: "Cargo", value: invoice.cargoID) }
                        if invoice.shipmentID != "—" { DetailRow(label: invoice.isCustoms ? "Attached to shipment" : "Shipment", value: invoice.shipmentID) }
                        if invoice.discount > 0 {
                            DetailRow(label: "Discount", value: "\(invoice.discountPercentage)% (\(MockData.money(invoice.discount, currency: invoice.currency)))")
                        }
                    }

                    if let shareURL = invoice.shareURL {
                        // Download is a PDF of the invoice. Order forms have no PDF of their own, so they only share.
                        if invoice.typeLabel != "Order Form", let pdfURL = URL(string: shareURL.absoluteString + (shareURL.query == nil ? "?pdf=1" : "&pdf=1")) {
                            Link(destination: pdfURL) {
                                Label("Download PDF", systemImage: "arrow.down.doc")
                                    .font(.limu(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(LimuColors.copper)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        ShareLink(item: shareURL, subject: Text("\(invoice.isShipping ? "Global Access Trade" : "Limu") \(invoice.typeLabel) invoice \(invoice.id)"), message: Text("Your \(invoice.isShipping ? "Global Access Trade" : "Limu") \(invoice.typeLabel) invoice \(invoice.id)")) {
                            Label("Share Invoice", systemImage: "square.and.arrow.up")
                                .font(.limu(size: 14, weight: .bold))
                                .foregroundStyle(LimuColors.copper)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(LimuColors.copperWash)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let documentURL = invoice.documentURL {
                        Link(destination: documentURL) {
                            Label("Open Invoice Document", systemImage: "doc.text.magnifyingglass")
                                .font(.limu(size: 14, weight: .bold))
                                .foregroundStyle(LimuColors.copper)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(LimuColors.copperWash)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if !invoice.payments.isEmpty {
                        SectionCard("Payment History") {
                            ForEach(invoice.payments) { payment in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(MockData.money(payment.amount, currency: payment.currency)).font(.limu(size: 13, weight: .bold)).foregroundStyle(LimuColors.ink)
                                        Text("\(payment.date) · \(payment.transactionID)").font(.limu(size: 11)).foregroundStyle(LimuColors.secondary)
                                    }
                                    Spacer()
                                    StatusBadge(status: payment.status)
                                }
                                if payment.proofURLs.isEmpty == false || payment.canAddProof {
                                    HStack(spacing: 18) {
                                        ForEach(Array(payment.proofURLs.enumerated()), id: \.offset) { index, proofURL in
                                            Link(payment.proofURLs.count == 1 ? "View proof" : "Proof \(index + 1)", destination: proofURL)
                                        }
                                        if payment.canAddProof {
                                            Button(addingProofPaymentID == payment.apiID ? "Uploading…" : "Add another proof") {
                                                addingProofPaymentID = payment.apiID
                                                showingAddProofImporter = true
                                            }
                                            .disabled(addingProofPaymentID != nil)
                                        }
                                        Spacer()
                                    }
                                    .font(.limu(size: 12, weight: .semibold))
                                    .foregroundStyle(LimuColors.copper)
                                    .padding(.bottom, 6)
                                }
                            }
                        }
                    }

                    if invoice.status != "Paid" {
                        PrimaryButton(title: "Upload Payment Proof", action: onUpload)
                    }
                }
                .padding(16)
            }
        }
        .background(LimuColors.pageBackground)
        .fileImporter(isPresented: $showingAddProofImporter, allowedContentTypes: [.pdf, .jpeg, .png], allowsMultipleSelection: false) { result in
            guard let paymentID = addingProofPaymentID else { return }
            switch result {
            case .success(let urls):
                guard let url = urls.first else { addingProofPaymentID = nil; return }
                Task {
                    if await appState.addPaymentProof(paymentID: paymentID, fileURL: url) { onProofAdded() }
                    addingProofPaymentID = nil
                }
            case .failure(let error):
                appState.errorMessage = error.localizedDescription
                addingProofPaymentID = nil
            }
        }
    }
}

struct PaymentUploadView: View {
    @EnvironmentObject private var appState: AppState
    private enum UploadState { case form, uploading, success }

    let invoice: Invoice
    let onBack: () -> Void
    @State private var state: UploadState = .form
    @State private var notes = ""
    @State private var fileURL: URL?
    @State private var showingFileImporter = false

    init(invoice: Invoice, onBack: @escaping () -> Void) {
        self.invoice = invoice
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(backTitle: invoice.displayTitle, title: "Upload Payment Proof", onBack: onBack)
            ScrollView {
                if state == .success { successView } else { formView }
            }
        }
        .background(LimuColors.pageBackground)
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .jpeg, .png], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): fileURL = urls.first
            case .failure(let error): appState.errorMessage = error.localizedDescription
            }
        }
    }

    private var formView: some View {
        VStack(spacing: 14) {
            Text("Invoice: \(invoice.id) · Balance: \(MockData.money(invoice.balance, currency: invoice.currency))")
                .font(.limu(size: 12))
                .foregroundStyle(Color(hex: "482A28"))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LimuColors.copperWash)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(LimuColors.peach) }
            Text("The amount is the invoice balance and the submission date and time are recorded automatically. Attach the proof and add a note if needed.")
                .font(.limu(size: 11))
                .foregroundStyle(LimuColors.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text("PROOF OF PAYMENT").font(.limu(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(LimuColors.secondary)
                Button { showingFileImporter = true } label: {
                    Label(fileURL?.lastPathComponent ?? "Tap to select image or PDF", systemImage: fileURL == nil ? "paperclip" : "checkmark.circle.fill")
                        .font(.limu(size: 13, weight: .semibold))
                        .foregroundStyle(fileURL == nil ? LimuColors.secondary : LimuColors.copper)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(fileURL == nil ? Color(hex: "FAFAF9") : LimuColors.copperWash)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(fileURL == nil ? LimuColors.charcoal.opacity(0.2) : LimuColors.copper, style: StrokeStyle(lineWidth: 2, dash: [6])) }
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("NOTES (OPTIONAL)").font(.limu(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(LimuColors.secondary)
                TextEditor(text: $notes)
                    .font(.limu(size: 14))
                    .frame(height: 82)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(LimuColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(LimuColors.charcoal.opacity(0.15), lineWidth: 1.5) }
            }
            PrimaryButton(title: state == .uploading ? "Submitting…" : "Submit for Review", loading: state == .uploading, disabled: fileURL == nil) {
                state = .uploading
                Task {
                    guard let fileURL else { state = .form; return }
                    let success = await appState.uploadPayment(invoiceID: invoice.apiID, amount: invoice.balance, transactionID: "", notes: notes, fileURL: fileURL)
                    state = success ? .success : .form
                }
            }
        }
        .padding(20)
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.limu(size: 62))
                .foregroundStyle(LimuColors.copper)
            VStack(spacing: 6) {
                Text("Payment Submitted!").font(.limu(size: 18, weight: .bold)).foregroundStyle(LimuColors.copper)
                Text("Your payment proof is under review. We'll notify you once it's approved.")
                    .font(.limu(size: 13)).foregroundStyle(LimuColors.secondary).multilineTextAlignment(.center).lineSpacing(3)
            }
            Text("Status: Pending Review")
                .font(.limu(size: 12, weight: .semibold)).foregroundStyle(Color(hex: "482A28"))
                .padding(12).frame(maxWidth: .infinity).background(LimuColors.copperWash).clipShape(RoundedRectangle(cornerRadius: 10))
            Button("Back to Invoice", action: onBack)
                .font(.limu(size: 15, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 32).padding(.vertical, 13).background(LimuColors.copper).clipShape(RoundedRectangle(cornerRadius: 12)).buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .padding(.top, 90)
    }
}
