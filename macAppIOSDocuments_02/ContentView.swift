// ContentView.swift
// Главный контейнер с вкладками и модульной архитектурой (GPT-MODULAR v3.6)
import SwiftUI
import UIKit

extension Notification.Name {
    static let switchToGPTTab = Notification.Name("switchToGPTTab")
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var modules: [Module] = []
    @State private var isInitialized = false
    
    var body: some View {
        Group {
            if isInitialized {
                TabView(selection: $selectedTab) {
                    ForEach(modules.indices, id: \.self) { index in
                        modules[index].getView()
                            .tabItem {
                                VStack(spacing: 2) {
                                    Image(systemName: modules[index].icon)
                                    Text(modules[index].displayName)
                                        .font(.system(size: 10, design: .rounded))
                                }
                            }
                            .tag(index)
                    }
                }
                .accentColor(.pink)
                .onReceive(NotificationCenter.default.publisher(for: .switchToGPTTab)) { _ in
                    if let gptIndex = modules.firstIndex(where: { $0.name == "Tab4Module" }) {
                        selectedTab = gptIndex
                    }
                }
            } else {
                // Loading state
                VStack {
                    ProgressView()
                    Text("Загрузка модулей...")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
            }
        }
        .onAppear {
            logDisplayDiagnostics()
        }
        .task {
            await initializeApp()
        }
    }
    
    // MARK: - Display Diagnostics

    private func logDisplayDiagnostics() {
        let screen = UIScreen.main
        let bounds = screen.bounds
        let scale = screen.scale
        let nativeBounds = screen.nativeBounds
        let nativeScale = screen.nativeScale

        let device = UIDevice.current
        let model = device.model
        let systemVersion = device.systemVersion

        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first

        let windowBounds = window?.bounds ?? .zero
        let windowScale = window?.screen.scale ?? 0
        let safeArea = window?.safeAreaInsets ?? .zero
        print("━━━━━━━━━━ DISPLAY DIAGNOSTICS ━━━━━━━━━━")
        print("📱 Device:          \(model) iOS \(systemVersion)")
        print("📐 Screen bounds:   \(Int(bounds.width))×\(Int(bounds.height)) pt")
        print("🔢 Screen scale:    \(scale)x")
        print("🖥 Native bounds:   \(Int(nativeBounds.width))×\(Int(nativeBounds.height)) px")
        print("🔢 Native scale:    \(nativeScale)x")
        print("🪟 Window bounds:   \(Int(windowBounds.width))×\(Int(windowBounds.height)) pt")
        print("🔢 Window scale:    \(windowScale)x")
        print("📏 Safe area:       top=\(Int(safeArea.top)) bottom=\(Int(safeArea.bottom)) left=\(Int(safeArea.left)) right=\(Int(safeArea.right))")

        // Проверка — если scale и nativeScale совпадают, зума нет
        if scale == nativeScale {
            print("✅ Zoom mode:       OFF — масштаб нормальный")
        } else {
            print("⚠️ Zoom mode:       POSSIBLE — scale=\(scale) nativeScale=\(nativeScale)")
        }

        // Проверка размера — нормальный iPhone 14: 390×844
        if bounds.width < 340 {
            print("⚠️ Width < 340pt — скорее всего включён Display Zoom на устройстве!")
            print("   Исправление: Настройки → Экран и яркость → Вид → Стандартный")
        } else {
            print("✅ Width OK:        \(Int(bounds.width))pt — Display Zoom выключен")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    // MARK: - App Initialization (GPT-MODULAR)
    
    private func initializeApp() async {
        let registry = ModuleRegistry.shared
        
        // Register all modules
        do {
            try registry.register(Tab2Module())     // DOC
            try registry.register(AnalysisModule()) // Analysis
            try registry.register(Tab4Module())     // GPT
            
            info("All modules registered: 3", "initializeApp()", [:])
        } catch {
            log(error, "registry.register(module)", [:])
        }
        
        // Initialize all modules
        await registry.initializeAll()
        
        // Get modules for UI
        modules = registry.getAllModules()
        isInitialized = true
        
        info("App initialized", "initializeApp()", [:])
    }
}

#Preview {
    ContentView()
}
