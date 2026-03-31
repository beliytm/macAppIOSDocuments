// ContentView.swift
// Главный контейнер с вкладками и модульной архитектурой (GPT-MODULAR v3.6)
import SwiftUI

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
        .task {
            await initializeApp()
        }
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
