// App.swift
// Entry point for MyIOSAppEnglish
import SwiftUI

@main
struct MyIOSAppEnglishApp: App {

    // Bump this string whenever analysis logic changes — triggers auto-clear on next launch
    private let DATA_VERSION = "2026.03.31.v6"

    init() {
        clearIfDataVersionChanged()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func clearIfDataVersionChanged() {
        let key = "dataVersion"
        guard UserDefaults.standard.string(forKey: key) != DATA_VERSION else { return }

        // Version changed — clear analysis results
        // Keychain (API key) is untouched — stored separately
        // SalaryStorage (PDF files) is kept — no need to re-upload
        AnalysisStorage.shared.deleteAll()
        GPTLogger.shared.clearLogs()

        UserDefaults.standard.set(DATA_VERSION, forKey: key)
        print("🧹 Data version \(DATA_VERSION) — analysis cleared (API key & PDFs kept)")
    }
}
