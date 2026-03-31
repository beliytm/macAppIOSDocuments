// AnalysisModule.swift
import Foundation
import SwiftUI
import Charts
import Combine

// MARK: - Model

struct SalaryAnalysis: Identifiable, Codable {
    let id: UUID
    let documentId: UUID
    let documentName: String
    let dateFrom: Date
    let dateTo: Date
    let bruto: Double
    let netto: Double
    let normalHours: Double
    let irregularHours: Double
    let tax: Double
    let pension: Double
    let azv: Double
    let paww: Double
    let vacationPay: Double
    var nettoLoon: Double
    var arbeidskorting: Double
    var vakantiegeld: Double
    var ww: Double
    var wia: Double
    var vakantiedagen: Double
    var toeslagen: Double
    var vergoedingen: Double
    var zvw: Double
    var wga: Double
    var loonLBPH: Double
    var loonSV: Double
    var opbouwVakantiedagenUren: Double
    var loonOnregelmatig: Double
    var loonOverwerk: Double
    var needsReview: Bool

    var totalHours: Double { normalHours + irregularHours }
    var totalDeductions: Double { tax + pension + azv + paww + ww + wia + zvw + wga }
}

// MARK: - Storage

final class AnalysisStorage: ObservableObject {
    static let shared = AnalysisStorage()

    @Published var entries: [SalaryAnalysis] = []
    @Published var lastBatchIDs: Set<UUID> = []

    private let key = "salary_analysis_v1"
    private let analyzedKey = "salary_analyzed_ids"
    private let batchKey = "salary_last_batch_ids"

    private var analyzedIDs: Set<UUID> = []

    init() { load() }

    func isAnalyzed(_ documentId: UUID) -> Bool {
        analyzedIDs.contains(documentId)
    }

    func save(_ entry: SalaryAnalysis) {
        entries.removeAll { $0.documentId == entry.documentId }
        entries.append(entry)
        entries.sort { $0.dateFrom < $1.dateFrom }
        analyzedIDs.insert(entry.documentId)
        persist()
        persistAnalyzedIDs()
    }

    func setLastBatch(_ ids: Set<UUID>) {
        lastBatchIDs = ids
        let strings = ids.map { $0.uuidString }
        UserDefaults.standard.set(strings, forKey: batchKey)
    }

    var lastBatchEntries: [SalaryAnalysis] {
        entries.filter { lastBatchIDs.contains($0.documentId) }
    }

    func deleteAll() {
        entries.removeAll()
        analyzedIDs.removeAll()
        lastBatchIDs.removeAll()
        persist()
        UserDefaults.standard.removeObject(forKey: analyzedKey)
        UserDefaults.standard.removeObject(forKey: batchKey)
    }

    func persistPublic() {
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func persistAnalyzedIDs() {
        let strings = analyzedIDs.map { $0.uuidString }
        UserDefaults.standard.set(strings, forKey: analyzedKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([SalaryAnalysis].self, from: data) {
            entries = decoded.sorted { $0.dateFrom < $1.dateFrom }
        }
        if let strings = UserDefaults.standard.stringArray(forKey: analyzedKey) {
            analyzedIDs = Set(strings.compactMap { UUID(uuidString: $0) })
        }
        if let strings = UserDefaults.standard.stringArray(forKey: batchKey) {
            lastBatchIDs = Set(strings.compactMap { UUID(uuidString: $0) })
        }
    }
}

// MARK: - Analysis Module (GPT-MODULAR)

final class AnalysisModule: BaseModule {

    init() {
        super.init(
            name: "AnalysisModule",
            displayName: "Analysis",
            icon: "chart.bar.xaxis",
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
        AnyView(AnalysisView())
    }
}

// MARK: - Analysis View

struct DeductionInfo: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
    let title: String
    let description: String
}

struct DeductionInfoSheet: View {
    let info: DeductionInfo
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(info.color)
                        .frame(width: 14, height: 14)
                    Text(info.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }

                Text(info.description)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

let deductionInfos: [DeductionInfo] = [
    DeductionInfo(
        label: "Loonheffing",
        color: .red,
        title: "Loonheffing — Подоходный налог",
        description: "Налог на доходы физических лиц в Нидерландах. Удерживается работодателем с каждой выплаты. Размер зависит от уровня дохода и налоговой таблицы (Week/Maand)."
    ),
    DeductionInfo(
        label: "StiPP",
        color: .orange,
        title: "StiPP — Пенсионный фонд",
        description: "Stichting Pensioenfonds voor Personeelsdiensten — пенсионный фонд для временных работников. Взнос составляет ~7.5% от базовой зарплаты. Накапливается до выхода на пенсию."
    ),
    DeductionInfo(
        label: "AZV",
        color: .yellow,
        title: "AZV — Медицинское страхование",
        description: "Algemene Ziektekostenverzekering — обязательное медицинское страхование. Составляет ~0.7% от зарплаты. Даёт право на медицинскую помощь в Нидерландах."
    ),
    DeductionInfo(
        label: "PAWW",
        color: .purple,
        title: "PAWW — Доп. страхование занятости",
        description: "Private Aanvulling WW en WGA — дополнительное страхование на случай безработицы. Составляет 0.1% от зарплаты. Выплачивается при потере работы сверх стандартного WW."
    ),
    DeductionInfo(
        label: "WW",
        color: .teal,
        title: "WW — Страхование по безработице",
        description: "Werkloosheidswet — государственное страхование по безработице. Выплачивается при потере работы на определённый период в зависимости от стажа."
    ),
    DeductionInfo(
        label: "WIA",
        color: .indigo,
        title: "WIA — Страхование по нетрудоспособности",
        description: "Wet werk en inkomen naar arbeidsvermogen — страхование на случай длительной нетрудоспособности (более 2 лет болезни). Взнос удерживается из зарплаты."
    ),
    DeductionInfo(
        label: "ZVW",
        color: .green,
        title: "ZVW — Закон о медицинском страховании",
        description: "Zorgverzekeringswet — закон об обязательном медицинском страховании. Работодатель платит взнос ZVW за работника. В расчётном листке часто отображается как отрицательное значение — это возмещение от работодателя."
    ),
    DeductionInfo(
        label: "WGA",
        color: .brown,
        title: "WGA — Частичная нетрудоспособность",
        description: "Werkhervattingsregeling Gedeeltelijk Arbeidsgeschikten — страхование для работников с частичной утратой трудоспособности. Взнос может делиться между работником и работодателем."
    ),
]

struct AnalysisView: View {
    @ObservedObject private var store = AnalysisStorage.shared
    @State private var selectedTab = 0
    @State private var showClearConfirm = false
    @State private var selectedInfo: DeductionInfo?

    private let eurFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "€"
        f.maximumFractionDigits = 2
        return f
    }()

    private let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        return f
    }()

    private var activeEntries: [SalaryAnalysis] {
        selectedTab == 0 ? store.lastBatchEntries : store.entries
    }

    private var totalNetto: Double { activeEntries.reduce(0) { $0 + $1.netto } }
    private var totalBruto: Double { activeEntries.reduce(0) { $0 + $1.bruto } }
    private var totalHours: Double { activeEntries.reduce(0) { $0 + $1.totalHours } }
    private var totalTax: Double { activeEntries.reduce(0) { $0 + $1.tax } }
    private var totalPension: Double { activeEntries.reduce(0) { $0 + $1.pension } }
    private var totalAzv: Double { activeEntries.reduce(0) { $0 + $1.azv } }
    private var totalPaww: Double { activeEntries.reduce(0) { $0 + $1.paww } }
    private var totalWw: Double { activeEntries.reduce(0) { $0 + $1.ww } }
    private var totalWia: Double { activeEntries.reduce(0) { $0 + $1.wia } }
    private var totalArbeidskorting: Double { activeEntries.reduce(0) { $0 + $1.arbeidskorting } }
    private var totalVakantiegeld: Double { activeEntries.reduce(0) { $0 + $1.vakantiegeld } }
    private var totalToeslagen: Double { activeEntries.reduce(0) { $0 + $1.toeslagen } }
    private var totalVergoedingen: Double { activeEntries.reduce(0) { $0 + $1.vergoedingen } }
    private var totalZvw: Double { activeEntries.reduce(0) { $0 + $1.zvw } }
    private var totalWga: Double { activeEntries.reduce(0) { $0 + $1.wga } }
    private var latestVacationPay: Double { activeEntries.last?.vacationPay ?? 0 }
    private var latestVakantiedagen: Double { activeEntries.last?.vakantiedagen ?? 0 }
    private var avgNetto: Double {
        guard !activeEntries.isEmpty else { return 0 }
        return totalNetto / Double(activeEntries.count)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Выбранные").tag(0)
                    Text("Все").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Group {
                    if activeEntries.isEmpty {
                        emptyState
                    } else {
                        content
                    }
                }
            }
            .onAppear {
                let existingIDs = Set(SalaryStorage.shared.documents.map { $0.id })
                let before = store.entries.count
                store.entries.removeAll { !existingIDs.contains($0.documentId) }
                if store.entries.count != before { store.persistPublic() }
            }
            .navigationTitle("Analysis")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !store.entries.isEmpty {
                        Button(action: { showClearConfirm = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .confirmationDialog("Очистить все данные анализа?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Очистить", role: .destructive) { store.deleteAll() }
                Button("Отмена", role: .cancel) { }
            }
            .sheet(item: $selectedInfo) { info in
                DeductionInfoSheet(info: info)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            Text("Нет данных")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.gray)
            Text("Выдели чеки в DOC и нажми ✦")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCards
                nettoChart
                deductionsCard
                hoursCard
                entriesList
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                summaryCard(title: "На карту итого", value: eur(totalNetto), color: .green, icon: "creditcard.fill")
                summaryCard(title: "Брутто итого", value: eur(totalBruto), color: .blue, icon: "briefcase.fill")
            }
            HStack(spacing: 10) {
                summaryCard(title: "Часы итого", value: String(format: "%.1f ч", totalHours), color: .orange, icon: "clock.fill")
                summaryCard(title: "Отпускные (сальдо)", value: eur(latestVacationPay), color: .pink, icon: "sun.max.fill")
            }
            HStack(spacing: 10) {
                summaryCard(title: "Vakantiegeld (отпускные)", value: eur(totalVakantiegeld), color: .cyan, icon: "banknote.fill")
                summaryCard(title: "Vakantiedagen (дни отпуска)", value: String(format: "%.2f д", latestVakantiedagen), color: .mint, icon: "calendar.badge.clock")
            }
            HStack(spacing: 10) {
                summaryCard(title: "Arbeidskorting (нал. льгота)", value: eur(totalArbeidskorting), color: .teal, icon: "percent")
                summaryCard(title: "Toeslagen (надбавки)", value: eur(totalToeslagen), color: .indigo, icon: "plus.circle.fill")
            }
            HStack(spacing: 10) {
                summaryCard(title: "Vergoedingen (компенсации)", value: eur(totalVergoedingen), color: .brown, icon: "arrow.uturn.left.circle.fill")
                Spacer().frame(maxWidth: .infinity)
            }
        }
    }

    private func summaryCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .cornerRadius(14)
    }

    // MARK: - Netto Chart

    private var nettoChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нетто по периодам")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Chart(activeEntries) { entry in
                BarMark(
                    x: .value("Период", periodLabel(entry)),
                    y: .value("Нетто €", entry.netto)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.pink, .pink.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(6)

                RuleMark(y: .value("Среднее", avgNetto))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.gray.opacity(0.5))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(eur(avgNetto))")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.gray)
                    }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("€\(Int(v))")
                                .font(.system(size: 10, design: .rounded))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(String.self) {
                            Text(v)
                                .font(.system(size: 9, design: .rounded))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Deductions Card

    private var deductionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Удержания итого")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            VStack(spacing: 8) {
                deductionRow(info: deductionInfos[0], amount: totalTax)
                deductionRow(info: deductionInfos[1], amount: totalPension)
                deductionRow(info: deductionInfos[2], amount: totalAzv)
                deductionRow(info: deductionInfos[3], amount: totalPaww)
                deductionRow(info: deductionInfos[4], amount: totalWw)
                deductionRow(info: deductionInfos[5], amount: totalWia)
                deductionRow(info: deductionInfos[6], amount: totalZvw)
                deductionRow(info: deductionInfos[7], amount: totalWga)
            }

            Divider()

            HStack {
                Text("Итого удержано")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(eur(totalTax + totalPension + totalAzv + totalPaww + totalWw + totalWia + totalZvw + totalWga))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func deductionRow(info: DeductionInfo, amount: Double) -> some View {
        HStack {
            Circle()
                .fill(info.color)
                .frame(width: 8, height: 8)
            Text(info.label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.primary)
            Button(action: { selectedInfo = info }) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(eur(amount))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Hours Card

    private var hoursCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Часы")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", activeEntries.reduce(0) { $0 + $1.normalHours }))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Обычные")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", activeEntries.reduce(0) { $0 + $1.irregularHours }))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Нерегулярные")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40)

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", totalHours))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("Всего")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Entries List

    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("По периодам")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            ForEach(activeEntries.reversed()) { entry in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(entry.documentName)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                if entry.needsReview {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                }
                            }
                            Text("\(shortDate.string(from: entry.dateFrom)) — \(shortDate.string(from: entry.dateTo))")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                            if entry.needsReview {
                                Text("требует проверки")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(eur(entry.netto))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(entry.needsReview ? .orange : .green)
                            Text("на карту")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(entry.needsReview ? .orange.opacity(0.7) : .green.opacity(0.7))
                            if entry.nettoLoon > 0 && entry.nettoLoon != entry.netto {
                                Text("netto loon \(eur(entry.nettoLoon))")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Text("bruto \(eur(entry.bruto))")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        }
    }

    // MARK: - Helpers

    private func periodLabel(_ entry: SalaryAnalysis) -> String {
        shortDate.string(from: entry.dateFrom)
    }

    private func eur(_ value: Double) -> String {
        eurFormatter.string(from: NSNumber(value: value)) ?? "€\(value)"
    }
}
