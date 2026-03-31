// Tab2View.swift
import Foundation
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Combine

// MARK: - Model

struct SalaryDocument: Identifiable, Codable {
    let id: UUID
    var name: String
    var dateFrom: Date
    var dateTo: Date
    var fileName: String

    init(id: UUID = UUID(), name: String, dateFrom: Date, dateTo: Date, fileName: String) {
        self.id = id
        self.name = name
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.fileName = fileName
    }
}

// MARK: - Company Emoji Storage

final class CompanyEmojiStorage: ObservableObject {
    static let shared = CompanyEmojiStorage()

    @Published private(set) var emojis: [String: String] = [:]
    private let key = "company_emojis_v1"

    init() { load() }

    func emoji(for company: String) -> String {
        emojis[company] ?? "➖"
    }

    func set(_ emoji: String, for company: String) {
        emojis[company] = emoji
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(emojis, forKey: key)
    }

    private func load() {
        emojis = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}

// MARK: - Emoji Picker Sheet

struct CompanyEmojiPickerSheet: View {
    let companyName: String
    @ObservedObject private var emojiStore = CompanyEmojiStorage.shared
    @State private var custom: String = ""
    @Environment(\.dismiss) var dismiss

    private let presets = ["🥪","🧱","🦐"]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Компания: \(companyName)")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // current
                HStack(spacing: 12) {
                    Text(emojiStore.emoji(for: companyName))
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("Текущий")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(companyName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                }
                .padding(.horizontal)

                Divider()

                // preset grid
                Text("Выбери")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                    ForEach(presets, id: \.self) { emoji in
                        Button(action: {
                            emojiStore.set(emoji, for: companyName)
                            dismiss()
                        }) {
                            Text(emoji)
                                .font(.system(size: 28))
                                .padding(4)
                                .background(emojiStore.emoji(for: companyName) == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()

                // custom input
                Text("Или введи свой")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    TextField("😊", text: $custom)
                        .font(.system(size: 32))
                        .frame(width: 60, height: 44)
                        .multilineTextAlignment(.center)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .onChange(of: custom) { val in
                            // keep only first emoji character
                            if let first = val.unicodeScalars.first,
                               val.count > 1 {
                                custom = String(val.prefix(1))
                            }
                        }

                    Button("Применить") {
                        let trimmed = custom.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            emojiStore.set(String(trimmed.prefix(2)), for: companyName)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("Эмодзи компании")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .onAppear {
                custom = ""
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Storage

final class SalaryStorage: ObservableObject {
    static let shared = SalaryStorage()

    @Published var documents: [SalaryDocument] = []

    private let metaKey = "salary_documents_meta"
    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SalaryDocs", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        load()
    }

    func add(name: String, dateFrom: Date, dateTo: Date, sourceURL: URL) throws {
        let fileName = "\(UUID().uuidString).pdf"
        let dest = docsDir.appendingPathComponent(fileName)
        _ = sourceURL.startAccessingSecurityScopedResource()
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        let doc = SalaryDocument(name: name, dateFrom: dateFrom, dateTo: dateTo, fileName: fileName)
        documents.append(doc)
        documents.sort { $0.dateFrom > $1.dateFrom }
        save()
    }

    func update(_ doc: SalaryDocument) {
        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
            documents[idx] = doc
            documents.sort { $0.dateFrom > $1.dateFrom }
            save()
        }
    }

    func delete(_ doc: SalaryDocument) {
        let file = docsDir.appendingPathComponent(doc.fileName)
        try? FileManager.default.removeItem(at: file)
        documents.removeAll { $0.id == doc.id }
        AnalysisStorage.shared.entries.removeAll { $0.documentId == doc.id }
        AnalysisStorage.shared.persistPublic()
        save()
    }

    func fileURL(for doc: SalaryDocument) -> URL {
        docsDir.appendingPathComponent(doc.fileName)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: metaKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: metaKey),
              let decoded = try? JSONDecoder().decode([SalaryDocument].self, from: data) else { return }
        documents = decoded.sorted { $0.dateFrom > $1.dateFrom }
    }
}

// MARK: - Tab2 Module (GPT-MODULAR)

final class Tab2Module: BaseModule {

    init() {
        super.init(
            name: "Tab2Module",
            displayName: "DOC",
            icon: "doc.fill",
            dependencies: []
        )
    }

    override func initialize() async throws {
        try await super.initialize()
    }

    override func execute() async -> ModuleResult {
        return .success(nil)
    }

    override func cleanup() {
        super.cleanup()
    }

    override func getView() -> AnyView {
        AnyView(Tab2View())
    }
}

// MARK: - Main View

struct Tab2View: View {
    @ObservedObject private var storage = SalaryStorage.shared
    @ObservedObject private var emojiStore = CompanyEmojiStorage.shared
    @State private var showingAdd = false
    @State private var selectedDoc: SalaryDocument?
    @State private var editingDoc: SalaryDocument?
    @State private var emojiPickerCompany: String?
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var isGPTProcessing = false
    @State private var gptResultMessage = ""
    @State private var showGPTResult = false
    @State private var unknownFieldsMessage = ""
    @State private var showUnknownFields = false

    @KeychainStorage("gptApiKey") private var apiKey: String

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    var body: some View {
        NavigationView {
            Group {
                if storage.documents.isEmpty {
                    emptyState
                } else {
                    docList
                }
            }
            .navigationTitle(isSelecting ? "Выбрано: \(selectedIDs.count)" : "Зарплаты")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelecting {
                        Button("Отмена") {
                            isSelecting = false
                            selectedIDs.removeAll()
                        }
                        .foregroundColor(.pink)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelecting {
                        HStack(spacing: 16) {
                            Button(action: {
                                if apiKey.isEmpty {
                                    isSelecting = false
                                    selectedIDs.removeAll()
                                    NotificationCenter.default.post(name: .switchToGPTTab, object: nil)
                                } else {
                                    extractDatesWithGPT()
                                }
                            }) {
                                if isGPTProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(selectedIDs.isEmpty ? .gray : .pink)
                                }
                            }
                            .disabled(selectedIDs.isEmpty || isGPTProcessing)

                            Button(action: deleteSelected) {
                                Image(systemName: "trash")
                                    .foregroundColor(selectedIDs.isEmpty ? .gray : .red)
                            }
                            .disabled(selectedIDs.isEmpty)
                        }
                    } else {
                        Button(action: { showingAdd = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting && !selectedIDs.isEmpty {
                    Button(action: deleteSelected) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Удалить (\(selectedIDs.count))")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddDocumentView()
            }
            .sheet(item: $selectedDoc) { doc in
                PDFPreviewView(url: storage.fileURL(for: doc), title: doc.name)
            }
            .sheet(item: $editingDoc) { doc in
                EditDocumentView(doc: doc)
            }
            .sheet(isPresented: Binding(
                get: { emojiPickerCompany != nil },
                set: { if !$0 { emojiPickerCompany = nil } }
            )) {
                if let company = emojiPickerCompany {
                    CompanyEmojiPickerSheet(companyName: company)
                }
            }
            .alert(gptResultMessage, isPresented: $showGPTResult) {
                Button("OK", role: .cancel) { }
            }
            .alert("⚠️ Новые данные найдены", isPresented: $showUnknownFields) {
                Button("Понял", role: .cancel) { }
            } message: {
                Text(unknownFieldsMessage)
            }
        }
    }

    // Universal pre-extraction: finds the most critical values using broad patterns
    // that work across Dutch, English, German payslips from any company.
    // GPT-4o gets these as verified anchors so it cannot pick wrong column values.
    static func buildUserPrompt(_ pdfText: String) -> String {
        var hints: [String] = []

        func firstNum(_ s: String) -> String? {
            s.range(of: #"[\d]+[.,][\d]+"#, options: .regularExpression).map { String(s[$0]) }
        }
        func toDouble(_ s: String) -> Double {
            Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        // 1. NET BANK TRANSFER (netto) — the amount the employee actually receives
        //    Covers Dutch flex, Dutch standard, English, German formats
        let nettoPatterns = [
            #"Netto te betalen\s+[\d]+[.,][\d]+"#,
            #"Te betalen\s*€?\s*[\d]+[.,][\d]+\s*per Bank"#,
            #"[Tt]o\s+be\s+paid\s*€?\s*[\d]+[.,][\d]+"#,
            #"[Nn]et\s+pay\s*:?\s*[\d]+[.,][\d]+"#,
            #"[Aa]uszahlungsbetrag\s*[\d]+[.,][\d]+"#,
            #"[Nn]et\s+salary\s+payable\s*[\d]+[.,][\d]+"#,
        ]
        var nettoVal: Double = 0
        for p in nettoPatterns {
            if let m = pdfText.range(of: p, options: .regularExpression),
               let n = firstNum(String(pdfText[m])) {
                hints.append("NET BANK TRANSFER (→ netto): \(n)")
                nettoVal = toDouble(n)
                break
            }
        }

        // 2. GROSS SALARY (bruto) — total earned before deductions, current period only
        let brutoPatterns = [
            #"[Tt]otaal\s+bruto\s+loon\s+[\d]+[.,][\d]+"#,
            #"[Tt]otal\s+gross\s+salary\s+[\d]+[.,][\d]+"#,
            #"[Gg]ross\s+pay\s*:?\s*[\d]+[.,][\d]+"#,
            #"[Gg]ross\s+salary\s*:?\s*[\d]+[.,][\d]+"#,
            #"[Bb]ruto\s+loon\s+[\d]+[.,][\d]+"#,
            #"[Gg]esamt(?:brutto|lohn)\s*[\d]+[.,][\d]+"#,
        ]
        for p in brutoPatterns {
            if let m = pdfText.range(of: p, options: .regularExpression),
               let n = firstNum(String(pdfText[m])) {
                hints.append("GROSS SALARY (→ bruto): \(n)")
                break
            }
        }

        // 3. NET WAGE BEFORE ALLOWANCES (nettoLoon) — intermediate value before travel is added
        var nettoLoonVal: Double = 0
        for p in [#"(?m)^Netto\s+loon\s+[\d]+[.,][\d]+"#, #"(?m)^Net\s+salary\s+[\d]+[.,][\d]+"#,
                  #"[Nn]etto\s+loon\s*:?\s*[\d]+[.,][\d]+"#] {
            if let m = pdfText.range(of: p, options: .regularExpression),
               let n = firstNum(String(pdfText[m])) {
                hints.append("NET WAGE BEFORE ALLOWANCES (→ nettoLoon): \(n)")
                nettoLoonVal = toDouble(n)
                break
            }
        }

        // 4. TRAVEL / COST REIMBURSEMENT (vergoedingen)
        //    Method A: find explicit travel/reimbursement line
        //    Dutch payslips show: "Reiskostenvergoedingen X,XX X,XX" when it's in Mutatie (2 numbers)
        //    If only 1 number → it's cumulative-only (not paid this period) → skip
        var vergoedFound = false
        // Look for travel lines INSIDE the payslip table (they have an RT code digit before amounts).
        // Table format: "Reiskostenvergoedingen 7 108,46 108,46"  ← RT code "7", then 2 amounts
        // Header format: "Reiskostenvergoedingen 108,46"           ← no RT code, 1 amount (skip)
        // English table: "Travel allowance 7 121,90 121,90"        ← same structure
        // \w+ ensures word-only match (no "week 12" etc.) so RT code digit follows immediately
        let vergoedPatterns = [
            #"[Rr]eiskosten\w+\s+\d+[T*]?\s+([\d]+[.,][\d]+)\s+([\d]+[.,][\d]+)"#,
            #"[Tt]ravel\s+allowance\s+\d+[T*]?\s+([\d]+[.,][\d]+)\s+([\d]+[.,][\d]+)"#,
            #"[Ff]ahrgeld\w*\s+\d+[T*]?\s+([\d]+[.,][\d]+)\s+([\d]+[.,][\d]+)"#,
        ]
        for p in vergoedPatterns {
            if let m = pdfText.range(of: p, options: .regularExpression) {
                let row = String(pdfText[m])
                let allNums = row.matches(of: #/(\d+[.,]\d+)/#).compactMap { String(row[$0.range]) }
                // first number = Mutatie column value
                if let first = allNums.first {
                    hints.append("TRAVEL REIMBURSEMENT (→ vergoedingen, MUTATIE): \(first)")
                    vergoedFound = true
                }
                break
            }
        }
        // Method B: compute from nettoLoon if available
        if !vergoedFound, nettoLoonVal > 0, nettoVal > nettoLoonVal + 0.01 {
            let verg = nettoVal - nettoLoonVal
            hints.append(String(format: "TRAVEL REIMBURSEMENT computed (netto - nettoLoon → vergoedingen): %.2f", verg))
            vergoedFound = true
        }
        if !vergoedFound { hints.append("TRAVEL REIMBURSEMENT: 0") }

        // 5. INCOME/WAGE TAX (tax) — always negative deduction
        let taxPatterns = [
            #"[Ll]oonheffingen?[^\n]+-[\d]+[.,][\d]+"#,
            #"[Ww]age\s+tax(?:es)?[^\n]+-[\d]+[.,][\d]+"#,
            #"[Ii]ncome\s+tax[^\n]+-[\d]+[.,][\d]+"#,
            #"[Ll]ohnsteuer[^\n]+-[\d]+[.,][\d]+"#,
            #"[Pp]ayroll\s+tax[^\n]+-[\d]+[.,][\d]+"#,
        ]
        var taxFound = false
        for p in taxPatterns {
            if let m = pdfText.range(of: p, options: .regularExpression) {
                let row = String(pdfText[m])
                if let neg = row.range(of: #"-[\d]+[.,][\d]+"#, options: .regularExpression) {
                    hints.append("INCOME TAX (→ tax, positive): \(String(row[neg]).replacingOccurrences(of: "-", with: ""))")
                    taxFound = true
                    break
                }
            }
        }
        if !taxFound { hints.append("INCOME TAX: 0") }

        // 6. DISABILITY / WGA insurance
        for p in [#"[Gg]ediff\.\s*premie\s*[Ww]hk[^\n]+-[\d]+[.,][\d]+"#,
                  #"\bWGA\b[^\n]+-[\d]+[.,][\d]+"#] {
            if let m = pdfText.range(of: p, options: .regularExpression) {
                let row = String(pdfText[m])
                if let neg = row.range(of: #"-[\d]+[.,][\d]+"#, options: .regularExpression) {
                    hints.append("WGA (→ wga, positive): \(String(row[neg]).replacingOccurrences(of: "-", with: ""))")
                    break
                }
            }
        }

        // 7. VACATION PAY ROW — 3 numbers: old balance | accrued this period | new balance
        let vakPatterns = [
            #"(?:[Vv]akantiegeld|[Vv]acation\s+(?:pay|allowance)|[Uu]rlaubsgeld)[^\n]*%\s+[\d]+[.,][\d]+\s+[\d]+[.,][\d]+\s+[\d]+[.,][\d]+"#,
        ]
        for p in vakPatterns {
            if let m = pdfText.range(of: p, options: .regularExpression) {
                let mt = String(pdfText[m])
                let nums = mt.matches(of: #/(\d+[.,]\d+)/#).compactMap { String(mt[$0.range]) }
                // nums[0]=percentage, [1]=old, [2]=accrued, [3]=new  OR  [0]=old, [1]=accrued, [2]=new
                let rel = nums.count > 3 ? Array(nums.dropFirst()) : nums
                if rel.count >= 3 {
                    hints.append("VACATION PAY: old=\(rel[0]) | ACCRUED_THIS_PERIOD(vakantiegeld)=\(rel[1]) | NEW_BALANCE(vacationPay)=\(rel[2])")
                }
                break
            }
        }

        // 8. VACATION DAYS ROW — 3 time values: old | accrued | new balance
        for p in [#"[Vv]akantiedagen[^\n]*?(\d+:\d+)\s+(\d+:\d+)\s+(\d+:\d+)"#,
                  #"[Vv]acation\s*days?[^\n]*?(\d+:\d+)\s+(\d+:\d+)\s+(\d+:\d+)"#] {
            if let m = pdfText.range(of: p, options: .regularExpression) {
                let mt = String(pdfText[m])
                let times = mt.matches(of: #/(\d+:\d+)/#).prefix(3).compactMap { String(mt[$0.range]) }
                if times.count >= 3 {
                    hints.append("VACATION DAYS: old=\(times[0]) | accrued=\(times[1]) | NEW_BALANCE(vakantiedagen)=\(times[2])")
                }
                break
            }
        }

        // 9. NORMAL HOURS — header or table line showing regular hours as HH:MM
        for p in [#"[Ll]oon\s+normale\s+uren\s+(\d+:\d+)"#, #"[Nn]ormal(?:\s+hours?)?\s+(\d+:\d+)"#,
                  #"[Rr]egular\s+hours?\s+(\d+:\d+)"#] {
            if let m = pdfText.range(of: p, options: .regularExpression) {
                let row = String(pdfText[m])
                if let tr = row.range(of: #"\d+:\d+"#, options: .regularExpression) {
                    hints.append("NORMAL HOURS (→ normalHours, convert HH:MM to decimal): \(row[tr])")
                }
                break
            }
        }

        // 10. IRREGULAR HOURS — sum ALL lines (multiple rates possible in one payslip)
        var totalIrreg: Double = 0
        var irrStart = pdfText.startIndex
        let irrPat = #"[Ll]oon\s+onregelmatige\s+uren\s+(\d+:\d+)|[Ii]rregular\s+hours?\s+(\d+:\d+)"#
        while let m = pdfText.range(of: irrPat, options: .regularExpression, range: irrStart..<pdfText.endIndex) {
            let row = String(pdfText[m])
            if let tr = row.range(of: #"\d+:\d+"#, options: .regularExpression) {
                let parts = row[tr].split(separator: ":").compactMap { Double($0) }
                if parts.count == 2 { totalIrreg += parts[0] + parts[1] / 60 }
            }
            irrStart = m.upperBound
        }
        if totalIrreg > 0 { hints.append(String(format: "IRREGULAR HOURS total (→ irregularHours): %.2f", totalIrreg)) }

        // 11. PAY PERIOD DATES
        for p in [#"[Pp]eriode?[:\s]+(\d{1,2}[-./]\d{1,2}[-./]\d{2,4})\s*(?:t/m|tot|until|-|–|to)\s*(\d{1,2}[-./]\d{1,2}[-./]\d{2,4})"#,
                  #"[Pp]eriod[:\s]+(\d{1,2}[-./]\d{1,2}[-./]\d{2,4})\s*(?:to|-|–)\s*(\d{1,2}[-./]\d{1,2}[-./]\d{2,4})"#,
                  #"[Zz]eitraum[:\s]+(\d{1,2}[-./]\d{1,2}[-./]\d{2,4})\s*(?:bis|-|–)\s*(\d{1,2}[-./]\d{1,2}[-./]\d{2,4})"#] {
            if let m = pdfText.range(of: p, options: .regularExpression) {
                hints.append("PAY PERIOD: \(pdfText[m])")
                break
            }
        }

        let header = hints.isEmpty ? "" :
            "=== KEY VALUES (verified from PDF — use these as ground truth) ===\n"
            + hints.joined(separator: "\n")
            + "\n\n=== FULL PAYSLIP TEXT ===\n"
        return header + String(pdfText.prefix(8000))
    }

    private func extractDatesWithGPT() {
        guard !apiKey.isEmpty else { return }

        let docs = storage.documents.filter { selectedIDs.contains($0.id) }
        guard !docs.isEmpty else { return }

        isGPTProcessing = true

        Task {
            var updated = 0
            var replaced = 0
            var failed = 0
            var failedNames: [String] = []
            var analyzedInBatch: Set<UUID> = []
            for doc in docs {
                info("analyzeWithGPT started", "extractDatesWithGPT()", ["doc": doc.name])

                let wasAnalyzed = AnalysisStorage.shared.isAnalyzed(doc.id)

                let fileURL = storage.fileURL(for: doc)
                guard let pdfDoc = PDFDocument(url: fileURL) else {
                    warn("PDFDocument init failed", "PDFDocument(url: fileURL)", ["fileURL": fileURL.path])
                    failed += 1
                    failedNames.append(doc.name + " (файл не найден)")
                    continue
                }

                var pdfText = ""
                for i in 0..<pdfDoc.pageCount {
                    if let page = pdfDoc.page(at: i) {
                        pdfText += page.string ?? ""
                    }
                }

                info("PDF text extracted", "pdfDoc.page(at: i).string", ["textLength": pdfText.count, "pages": pdfDoc.pageCount])

                guard !pdfText.isEmpty else {
                    warn("PDF text is empty", "pdfText.isEmpty", ["doc": doc.name])
                    failed += 1
                    failedNames.append(doc.name + " (PDF не содержит текста, возможно скан)")
                    continue
                }

                let systemPrompt = """
                You are a universal payslip extractor. You can read payslips in ANY language (Dutch, English, German, French, etc.) from ANY company. Return ONLY valid JSON — no markdown, no explanation, nothing else.

                ## OUTPUT SCHEMA
                Every field is required. Use 0.0 for missing numbers, "" for missing strings.
                {
                  "dateFrom": "YYYY-MM-DD",
                  "dateTo": "YYYY-MM-DD",
                  "companyName": "",
                  "bruto": 0.0,
                  "netto": 0.0,
                  "nettoLoon": 0.0,
                  "tax": 0.0,
                  "pension": 0.0,
                  "azv": 0.0,
                  "paww": 0.0,
                  "arbeidskorting": 0.0,
                  "vakantiegeld": 0.0,
                  "vacationPay": 0.0,
                  "ww": 0.0,
                  "wia": 0.0,
                  "vakantiedagen": 0.0,
                  "toeslagen": 0.0,
                  "vergoedingen": 0.0,
                  "zvw": 0.0,
                  "wga": 0.0,
                  "loonLBPH": 0.0,
                  "loonSV": 0.0,
                  "opbouwVakantiedagenUren": 0.0,
                  "normalHours": 0.0,
                  "irregularHours": 0.0,
                  "loonOnregelmatig": 0.0,
                  "loonOverwerk": 0.0,
                  "extra": {}
                }

                ## RULE 1 — NETTO (most critical field)
                netto = the EXACT amount transferred to the employee's bank account.
                The pre-extracted hint "NET BANK TRANSFER" above is the authoritative value — always use it.
                Dutch: "Netto te betalen X,XX" or "Te betalen € X,XX per Bank" or on page 2 "Te betalen per Bank EU".
                English: "Net pay", "To be paid", "Net salary payable".
                German: "Auszahlungsbetrag".
                netto INCLUDES travel reimbursements added after tax deductions.
                NEVER use a year-to-date / cumulative value for netto.

                ## RULE 2 — BRUTO
                bruto = total gross earnings this pay period only (NOT year-to-date).
                Dutch: "Totaal bruto loon" — take the FIRST number (= current period / Mutatie column).
                English: "Total gross salary", "Gross pay".
                When multiple columns exist (Mutatie | Totaal tijdvak | Verrekenen): ALWAYS use Mutatie (first column). "Totaal tijdvak" is cumulative — never use it for bruto.

                ## RULE 3 — COLUMN SELECTION (Dutch payslips)
                Dutch payslips often show: Mutatie | Totaal tijdvak | Verrekenen
                Mutatie = this period → USE THIS for all monetary fields
                Totaal tijdvak = year-to-date cumulative → NEVER use for field values
                Exception: loonLBPH and loonSV come from the year-to-date cumulative table at the bottom (that is their correct source).

                ## RULE 4 — FIELD CONCEPTS (language-agnostic)
                nettoLoon    = net wage BEFORE travel/cost reimbursements; set 0 if same as netto or absent
                tax          = wage/income tax withheld (positive). Dutch: Loonheffingen. English: Wage tax. German: Lohnsteuer.
                pension      = pension contribution deducted (positive). Dutch: StiPP Pensioen. German: Rentenversicherung.
                azv          = Dutch health insurance AZV premium (positive, 0 if not Dutch)
                paww         = Dutch PAWW supplemental unemployment insurance (positive, 0 if not Dutch)
                arbeidskorting = Dutch employment tax credit (positive, from "Overige" section or separate line)
                zvw          = Dutch ZVW healthcare contribution (positive)
                wga          = Dutch WGA partial disability insurance (positive). Line: "Gediff. premie Whk WGA".
                wia          = disability insurance only if explicitly deducted as a line item (else 0)
                ww           = ALWAYS 0 — unemployment insurance appears in cumulative tables but is NOT deducted from individual pay
                vergoedingen = travel/cost reimbursements added to net pay (positive). Dutch: Reiskosten, Reiskostenvergoeding. English: Travel allowance.
                toeslagen    = allowances/supplements (NOT travel). Dutch: Toeslagen. English: Allowances.
                companyName  = the EMPLOYER name (Werkgever / Employer). NOT the client/inlener company.

                ## RULE 5 — VACATION PAY (critical: 3 numbers on one row)
                The vacation pay row format: [label] [%] [Old balance] [Accrued this period] [New balance]
                Example: "Vakantiegeld 8,00000% 88,69 37,69 126,38"
                  vakantiegeld = 37.69  (2nd number = ACCRUED THIS PERIOD only)
                  vacationPay  = 126.38 (3rd number = NEW BALANCE)
                The pre-extracted hint "VACATION PAY" above shows the correct values. Never swap these.

                ## RULE 6 — HOURS
                Convert HH:MM to decimal: MM/60. Examples: 6:45=6.75, 4:30=4.5, 10:22=10.37, 28:00=28.0
                normalHours    = regular/normal hours this period (NOT hourly rate, NOT year-to-date)
                irregularHours = SUM of ALL irregular/onregelmatige/overtime lines this period
                For "6:45 à 150% 15,52": irregularHours += 6.75 (the hours), NOT 15.52 (the rate/amount)
                loonOnregelmatig = euro AMOUNT for irregular hours (from Mutatie column)
                loonOverwerk = euro AMOUNT for overtime hours (from Mutatie column)
                opbouwVakantiedagenUren = vacation hours accrued this period (decimal)
                vakantiedagen = vacation days NEW BALANCE in decimal hours

                ## RULE 7 — CUMULATIVE FIELDS
                loonLBPH = "Loon LB/PH" or "LB/PH wage" from the year-to-date cumulatives table
                loonSV   = "Loon SV" or "SV wage" from the year-to-date cumulatives table

                ## RULE 8 — VERGOEDINGEN CALCULATION
                If vergoedingen is not found explicitly but netto > bruto:
                  vergoedingen = netto - nettoLoon  (if nettoLoon available)
                  OR vergoedingen = netto - bruto   (as fallback)

                ## RULE 9 — EXTRA
                extra = {} only for NUMERIC values not covered by any field above.
                Do NOT put: IBAN, BSN, phone numbers, addresses, percentages, year-to-date cumulative-only values, or text in extra.

                ## ALL DEDUCTIONS are positive numbers. Missing = 0.0. Missing strings = "".
                """

                let userPrompt = Self.buildUserPrompt(pdfText)

                var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
                req.httpMethod = "POST"
                req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: [
                    "model": "gpt-5.4",
                    "messages": [
                        ["role": "system", "content": systemPrompt],
                        ["role": "user", "content": userPrompt]
                    ],
                    "max_completion_tokens": 2000,
                    "response_format": ["type": "json_object"]
                ] as [String: Any])

                let (gptResult, apiError) = await callGPTWithRetry(request: req, docName: doc.name)

                guard var result = gptResult else {
                    failed += 1; failedNames.append(doc.name + " (\(apiError))")
                    continue
                }

                // GPT may return integers instead of doubles — handle both
                func num(_ key: String) -> Double {
                    if let d = result[key] as? Double { return d }
                    if let i = result[key] as? Int { return Double(i) }
                    return 0
                }

                let isoFmt = ISO8601DateFormatter()
                isoFmt.formatOptions = [.withFullDate]

                var updatedDoc = doc
                if let fromStr = result["dateFrom"] as? String, let from = isoFmt.date(from: fromStr) {
                    updatedDoc.dateFrom = from
                }
                if let toStr = result["dateTo"] as? String, let to = isoFmt.date(from: toStr) {
                    updatedDoc.dateTo = to
                }
                if let company = result["companyName"] as? String, !company.isEmpty {
                    updatedDoc.name = company
                }
                await MainActor.run { storage.update(updatedDoc) }

                let bruto = num("bruto")
                let rawNetto = num("netto")
                let rawNettoLoon = num("nettoLoon")
                let rawVergoedingen = num("vergoedingen")
                let toeslagen = num("toeslagen")

                let netto: Double = rawNetto > 0 ? rawNetto : bruto

                // nettoLoon is invalid if GPT confused it with bruto/netto
                let nettoLoon: Double = {
                    guard rawNettoLoon > 0, rawNettoLoon < netto, rawNettoLoon != bruto else { return 0 }
                    return rawNettoLoon
                }()

                // If netto > bruto and GPT missed vergoedingen (e.g. reiskosten not in MUTATIE),
                // compute it automatically — the difference is logically travel allowance
                let vergoedingen: Double = {
                    if rawVergoedingen > 0 { return rawVergoedingen }
                    let surplus = netto - bruto - toeslagen
                    return surplus > 0.5 ? surplus : 0
                }()

                let entry = SalaryAnalysis(
                    id: UUID(),
                    documentId: doc.id,
                    documentName: updatedDoc.name,
                    dateFrom: updatedDoc.dateFrom,
                    dateTo: updatedDoc.dateTo,
                    bruto: bruto,
                    netto: netto,
                    normalHours: num("normalHours"),
                    irregularHours: num("irregularHours"),
                    tax: num("tax"),
                    pension: num("pension"),
                    azv: num("azv"),
                    paww: num("paww"),
                    vacationPay: num("vacationPay"),
                    nettoLoon: nettoLoon,
                    arbeidskorting: num("arbeidskorting"),
                    vakantiegeld: num("vakantiegeld"),
                    ww: num("ww"),
                    wia: num("wia"),
                    vakantiedagen: num("vakantiedagen"),
                    toeslagen: toeslagen,
                    vergoedingen: vergoedingen,
                    zvw: num("zvw"),
                    wga: num("wga"),
                    loonLBPH: num("loonLBPH"),
                    loonSV: num("loonSV"),
                    opbouwVakantiedagenUren: num("opbouwVakantiedagenUren"),
                    loonOnregelmatig: num("loonOnregelmatig"),
                    loonOverwerk: num("loonOverwerk"),
                    needsReview: bruto == 0 || (netto > bruto + vergoedingen + 1)
                )
                if entry.needsReview {
                    await MainActor.run {
                        gptResultMessage = "⚠ «\(updatedDoc.name)»: данные требуют проверки (bruto=\(entry.bruto), netto=\(entry.netto))"
                        showGPTResult = true
                    }
                }

                await MainActor.run {
                    AnalysisStorage.shared.save(entry)
                }
                analyzedInBatch.insert(doc.id)
                if wasAnalyzed { replaced += 1 } else { updated += 1 }

                if let extra = result["extra"] as? [String: Any] {
                    // only show numeric values — skip IBAN, text fields, multi-value strings
                    let numericExtra = extra.filter { _, v in
                        if let n = v as? Double { return n != 0 }
                        if let n = v as? Int { return n != 0 }
                        return false
                    }
                    if !numericExtra.isEmpty {
                        let lines = numericExtra.map { "• \($0.key): \($0.value)" }.sorted().joined(separator: "\n")
                        await MainActor.run {
                            unknownFieldsMessage = "В документе «\(doc.name)» найдены данные которые не учитываются:\n\n\(lines)\n\nСообщи разработчику чтобы добавить их в анализ."
                            showUnknownFields = true
                        }
                    }
                }
            }

            await MainActor.run {
                if !analyzedInBatch.isEmpty {
                    AnalysisStorage.shared.setLastBatch(analyzedInBatch)
                }
                isGPTProcessing = false
                isSelecting = false
                selectedIDs.removeAll()
                var msg = ""
                if updated > 0 { msg += "✅ Проанализировано: \(updated)" }
                if replaced > 0 { msg += (msg.isEmpty ? "" : "\n") + "🔄 Пересчитано: \(replaced) (данные обновлены)" }
                if failed > 0 {
                    msg += (msg.isEmpty ? "" : "\n") + "⚠ Ошибка (\(failed)):"
                    for name in failedNames { msg += "\n• \(name)" }
                }
                if msg.isEmpty { msg = "Не удалось извлечь данные" }
                gptResultMessage = msg
                showGPTResult = true
            }
        }
    }

    // Returns (result, errorMessage). errorMessage is non-empty only on failure.
    // Does NOT fall back between models — caller (extractDatesWithGPT) handles model fallback.
    private func callGPTWithRetry(
        request: URLRequest,
        docName: String,
        attempt: Int = 1
    ) async -> (result: [String: Any]?, error: String) {
        let MAX_ATTEMPTS = 3
        info("GPT request attempt \(attempt)", "callGPTWithRetry()", ["doc": docName])

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            warn("network failed attempt \(attempt)", "URLSession.shared.data(for: request)", ["doc": docName])
            if attempt < MAX_ATTEMPTS {
                try? await Task.sleep(nanoseconds: UInt64(1_500_000_000 * attempt))
                return await callGPTWithRetry(request: request, docName: docName, attempt: attempt + 1)
            }
            return (nil, "сеть недоступна")
        }

        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
        info("GPT response", "URLSession.shared.data(for: request)", ["status": httpStatus, "bytes": data.count])

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            warn("response JSON parse failed attempt \(attempt)", "JSONSerialization.jsonObject(with: data)", ["doc": docName])
            if attempt < MAX_ATTEMPTS {
                try? await Task.sleep(nanoseconds: UInt64(1_500_000_000 * attempt))
                return await callGPTWithRetry(request: request, docName: docName, attempt: attempt + 1)
            }
            return (nil, "HTTP \(httpStatus): не удалось прочитать ответ")
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let rawContent = (choices.first?["message"] as? [String: Any])?["content"] as? String else {
            let apiError = (json["error"] as? [String: Any])?["message"] as? String ?? "no choices"
            warn("no GPT content attempt \(attempt)", "json[choices][content]", ["error": apiError, "status": httpStatus])
            // Retry only on rate-limit or server errors — NOT on 400/404 (model unavailable)
            if attempt < MAX_ATTEMPTS && (httpStatus == 429 || httpStatus >= 500) {
                try? await Task.sleep(nanoseconds: UInt64(2_000_000_000 * attempt))
                return await callGPTWithRetry(request: request, docName: docName, attempt: attempt + 1)
            }
            return (nil, "HTTP \(httpStatus): \(apiError)")
        }

        info("GPT content ok", "choices[0].message.content", ["length": rawContent.count])

        let cleaned = extractJSON(from: rawContent)
        guard let jsonData = cleaned.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            warn("result parse failed attempt \(attempt)", "JSONSerialization.jsonObject(with: jsonData)", ["cleaned": String(cleaned.prefix(100))])
            if attempt < MAX_ATTEMPTS {
                try? await Task.sleep(nanoseconds: UInt64(1_500_000_000 * attempt))
                return await callGPTWithRetry(request: request, docName: docName, attempt: attempt + 1)
            }
            return (nil, "не удалось прочитать JSON из ответа")
        }

        return (resolveExtraFields(result), "")
    }

    private func resolveExtraFields(_ input: [String: Any]) -> [String: Any] {
        guard var extra = input["extra"] as? [String: Any], !extra.isEmpty else { return input }
        var result = input

        // field → [substrings that identify it] (lowercased)
        let aliases: [(field: String, patterns: [String])] = [
            ("paww",           ["paww"]),
            ("azv",            ["azv"]),
            ("pension",        ["stipp", "pensioen"]),
            ("tax",            ["loonheffing", "loonbelasting", "ib + iib", "ib+iib", "ib/pvv", "inkomstenbelasting"]),
            ("wga",            ["wga"]),
            ("zvw",            ["zvw", "iib", "inkomensafhankelijke"]),
            ("wia",            ["wia"]),
            ("ww",             ["premie ww", " ww ", "ww "]),
            ("toeslagen",      ["toeslag"]),
            ("vergoedingen",          ["vergoeding"]),
            ("arbeidskorting",        ["arbeidskorting"]),
            ("vakantiegeld",          ["vakantiegeld", "opgebouwd", "vakantie uitbetaal"]),
            ("vakantiedagen",         ["vakantiedagen saldo", "saldo vakantiedagen"]),
            ("loonLBPH",              ["loon lb/ph", "loon lb", "fiscaal loon", "loon loonbelasting"]),
            ("loonSV",                ["loon sv", "loon sociale"]),
            ("opbouwVakantiedagenUren", ["opbouw vakantiedagen"]),
            ("loonOnregelmatig",       ["onregelmatige uren", "loon onregelm"]),
            ("loonOverwerk",           ["overwerkuren", "overwerk loon", "loon overwerk"]),
        ]

        for (field, patterns) in aliases {
            for key in extra.keys {
                let lower = key.lowercased()
                guard patterns.contains(where: { lower.contains($0) }) else { continue }
                // handle both Double and Int from JSON
                let extraVal: Double
                if let d = extra[key] as? Double { extraVal = d }
                else if let i = extra[key] as? Int { extraVal = Double(i) }
                else { continue }
                let existing: Double
                if let d = result[field] as? Double { existing = d }
                else if let i = result[field] as? Int { existing = Double(i) }
                else { existing = 0 }
                if extraVal != 0 && existing == 0 {
                    result[field] = extraVal
                }
                extra.removeValue(forKey: key)
                break
            }
        }

        result["extra"] = extra
        return result
    }

    private func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // убираем markdown ```json ... ```
        if s.hasPrefix("```") {
            s = s.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
        }
        if s.hasSuffix("```") {
            s = s.components(separatedBy: "\n").dropLast().joined(separator: "\n")
        }
        // находим первый { и последний }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            return String(s[start...end])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deleteSelected() {
        for doc in storage.documents where selectedIDs.contains(doc.id) {
            storage.delete(doc)
        }
        selectedIDs.removeAll()
        isSelecting = false
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            Text("Нет документов")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.gray)
            Text("Нажмите + чтобы добавить PDF")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var docList: some View {
        List {
            ForEach(storage.documents) { doc in
                HStack(spacing: 12) {
                    if isSelecting {
                        Image(systemName: selectedIDs.contains(doc.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(selectedIDs.contains(doc.id) ? .pink : .gray)
                            .animation(.easeInOut(duration: 0.15), value: selectedIDs.contains(doc.id))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Button(action: {
                                if !isSelecting { emojiPickerCompany = doc.name }
                            }) {
                                Text(emojiStore.emoji(for: doc.name))
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)

                            Text(doc.name)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13))
                                .foregroundColor(.pink)
                            Text("\(dateFormatter.string(from: doc.dateFrom)) — \(dateFormatter.string(from: doc.dateTo))")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelecting {
                        if selectedIDs.contains(doc.id) {
                            selectedIDs.remove(doc.id)
                        } else {
                            selectedIDs.insert(doc.id)
                        }
                    } else {
                        selectedDoc = doc
                    }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    if !isSelecting {
                        isSelecting = true
                    }
                    selectedIDs.insert(doc.id)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !isSelecting {
                        Button(role: .destructive) {
                            storage.delete(doc)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if !isSelecting {
                        Button {
                            editingDoc = doc
                        } label: {
                            Label("Изменить", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Add Document View

struct AddDocumentView: View {
    @ObservedObject private var storage = SalaryStorage.shared
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var dateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var dateTo: Date = Date()
    @State private var showingPicker = false
    @State private var selectedURL: URL?
    @State private var errorMessage: String = ""
    @State private var showSuggestions = false

    private var suggestions: [String] {
        let all = storage.documents.map { $0.name }
        let unique = Array(NSOrderedSet(array: all)) as? [String] ?? []
        guard !name.isEmpty else { return unique }
        return unique.filter { $0.lowercased().contains(name.lowercased()) && $0 != name }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Название")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                    TextField("Например: Зарплата март 2026", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 16, design: .rounded))
                        .onChange(of: name) { _ in
                            showSuggestions = !suggestions.isEmpty
                        }

                    if showSuggestions && !suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    name = suggestion
                                    showSuggestions = false
                                }) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                        Text(suggestion)
                                            .font(.system(size: 15, design: .rounded))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                }
                                if suggestion != suggestions.last {
                                    Divider().padding(.leading, 36)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Период")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)

                    DatePicker("С", selection: $dateFrom, displayedComponents: .date)
                        .font(.system(size: 16, design: .rounded))
                        .environment(\.locale, Locale(identifier: "ru_RU"))

                    DatePicker("По", selection: $dateTo, in: dateFrom..., displayedComponents: .date)
                        .font(.system(size: 16, design: .rounded))
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                Button(action: { showingPicker = true }) {
                    HStack {
                        Image(systemName: selectedURL != nil ? "checkmark.circle.fill" : "doc.badge.plus")
                            .foregroundColor(selectedURL != nil ? .green : .pink)
                        Text(selectedURL != nil ? selectedURL!.lastPathComponent : "Выбрать PDF")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(selectedURL != nil ? .primary : .pink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(10)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.system(.caption, design: .rounded))
                }

                Button(action: save) {
                    Text("Сохранить")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.pink : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!canSave)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Новый документ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPicker) {
                DocumentPickerView(selectedURL: $selectedURL)
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && selectedURL != nil
    }

    private func save() {
        guard let url = selectedURL else { return }
        do {
            try storage.add(name: name.trimmingCharacters(in: .whitespaces),
                            dateFrom: dateFrom,
                            dateTo: dateTo,
                            sourceURL: url)
            dismiss()
        } catch {
            errorMessage = "Ошибка сохранения файла"
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURL = urls.first
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) var dismiss
    @State private var pdfView = PDFView()
    @State private var showCopied = false

    var body: some View {
        NavigationView {
            PDFKitView(url: url, pdfView: pdfView)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: copySelection) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .foregroundColor(showCopied ? .green : .pink)
                        }
                    }
                }
        }
    }

    private func copySelection() {
        guard let selection = pdfView.currentSelection,
              let text = selection.string, !text.isEmpty else { return }
        UIPasteboard.general.string = text
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    let pdfView: PDFView

    func makeUIView(context: Context) -> PDFView {
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.isUserInteractionEnabled = true
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Edit Document View

struct EditDocumentView: View {
    let doc: SalaryDocument
    @ObservedObject private var storage = SalaryStorage.shared
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var dateFrom: Date
    @State private var dateTo: Date
    @State private var showSuggestions = false

    init(doc: SalaryDocument) {
        self.doc = doc
        _name = State(initialValue: doc.name)
        _dateFrom = State(initialValue: doc.dateFrom)
        _dateTo = State(initialValue: doc.dateTo)
    }

    private var suggestions: [String] {
        let all = storage.documents.map { $0.name }
        let unique = Array(NSOrderedSet(array: all)) as? [String] ?? []
        guard !name.isEmpty else { return unique }
        return unique.filter { $0.lowercased().contains(name.lowercased()) && $0 != name }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Название")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                    TextField("Название", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 16, design: .rounded))
                        .onChange(of: name) { _ in
                            showSuggestions = !suggestions.isEmpty
                        }

                    if showSuggestions && !suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    name = suggestion
                                    showSuggestions = false
                                }) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                        Text(suggestion)
                                            .font(.system(size: 15, design: .rounded))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                }
                                if suggestion != suggestions.last {
                                    Divider().padding(.leading, 36)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Период")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                    DatePicker("С", selection: $dateFrom, displayedComponents: .date)
                        .font(.system(size: 16, design: .rounded))
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                    DatePicker("По", selection: $dateTo, in: dateFrom..., displayedComponents: .date)
                        .font(.system(size: 16, design: .rounded))
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                Button(action: save) {
                    Text("Сохранить")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.pink : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private func save() {
        var updated = doc
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.dateFrom = dateFrom
        updated.dateTo = dateTo
        storage.update(updated)
        dismiss()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
