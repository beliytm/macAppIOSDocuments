// ModuleRegistry.swift
// Реестр для регистрации и управления модулями (GPT-MODULAR v3.6)
import Foundation

// MARK: - Module Registry

final class ModuleRegistry {
    static let shared = ModuleRegistry()
    
    private var modules: [String: Module] = [:]
    private var registrationOrder: [String] = []  // Preserve registration order
    private var initialized: Set<String> = []
    private var initOrder: [String] = []
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register a module
    /// - Throws: ModuleError if module already registered or circular dependency detected
    func register(_ module: Module) throws {
        let name = module.name
        
        // Check duplicate
        guard modules[name] == nil else {
            let error = ModuleError.alreadyRegistered(name)
            log(error, "register(\(name))", ["existingModules": Array(modules.keys)])
            throw error
        }
        
        // Detect circular dependencies
        try detectCircularDependencies(module)
        
        modules[name] = module
        registrationOrder.append(name)  // Preserve order
        info("Module registered", "register(\(name))", [:])
    }
    
    /// Get module by name
    func get(_ name: String) -> Module? {
        return modules[name]
    }
    
    /// Get all registered modules in registration order
    func getAllModules() -> [Module] {
        // Return in registration order for UI consistency
        return registrationOrder.compactMap { modules[$0] }
    }
    
    // MARK: - Lifecycle
    
    /// Initialize all modules in dependency order
    @MainActor
    func initializeAll() async {
        initOrder = resolveDependencyOrder()
        
        info("Starting module initialization", "initializeAll()", [:])
        
        for name in initOrder {
            guard let module = modules[name] else { continue }
            
            do {
                try await module.initialize()
                initialized.insert(name)
                info("Module initialized: \(name)", "initializeAll()", [:])
            } catch {
                log(error, "await module.initialize()", ["module": name])
                // Continue with other modules (fail gracefully)
            }
        }
        
        info("Module initialization complete: \(initialized.count)/\(modules.count)", "initializeAll()", [:])
    }
    
    /// Execute all initialized modules
    @MainActor
    func executeAll() async -> [String: ModuleResult] {
        var results: [String: ModuleResult] = [:]
        
        for name in initOrder {
            guard let module = modules[name], initialized.contains(name) else { continue }
            
            let result = await module.execute()
            results[name] = result
            
            if case .failure(let error) = result {
                log(error, "await module.execute()", ["module": name])
            }
        }
        
        return results
    }
    
    /// Cleanup all modules in reverse order
    func cleanupAll() {
        let reverseOrder = initOrder.reversed()
        
        for name in reverseOrder {
            modules[name]?.cleanup()
        }
        
        initialized.removeAll()
        info("All modules cleaned up: \(modules.count)", "cleanupAll()", [:])
    }
    
    /// Reset registry (for testing)
    func reset() {
        cleanupAll()
        modules.removeAll()
        registrationOrder.removeAll()
        initOrder.removeAll()
    }
    
    // MARK: - Dependency Resolution
    
    /// Resolve dependency order using topological sort
    private func resolveDependencyOrder() -> [String] {
        var visited = Set<String>()
        var order: [String] = []
        
        func visit(_ name: String) {
            guard !visited.contains(name) else { return }
            visited.insert(name)
            
            if let module = modules[name] {
                for dep in module.dependencies {
                    visit(dep)
                }
                order.append(name)
            }
        }
        
        for name in modules.keys {
            visit(name)
        }
        
        return order
    }
    
    /// Detect circular dependencies before registration
    private func detectCircularDependencies(_ module: Module) throws {
        var visited = Set<String>()
        var path: [String] = []
        
        func check(_ name: String) throws {
            if path.contains(name) {
                let cyclePath = path.joined(separator: " -> ") + " -> " + name
                throw ModuleError.circularDependency(cyclePath)
            }
            
            guard !visited.contains(name) else { return }
            visited.insert(name)
            path.append(name)
            
            if let existingModule = modules[name] {
                for dep in existingModule.dependencies {
                    try check(dep)
                }
            }
            
            path.removeLast()
        }
        
        // Check the new module's dependencies
        path.append(module.name)
        for dep in module.dependencies {
            // Warn if dependency doesn't exist yet
            if modules[dep] == nil {
                warn(
                    "Dependency not yet registered",
                    "detectCircularDependencies(\(module.name))",
                    ["dependency": dep]
                )
            }
            try check(dep)
        }
    }
    
    // MARK: - Diagnostics
    
    /// Get registry status for debugging
    func getStatus() -> [String: Any] {
        return [
            "totalModules": modules.count,
            "initializedModules": initialized.count,
            "registrationOrder": registrationOrder,
            "initOrder": initOrder
        ]
    }
}

// MARK: - Convenience Extensions

extension ModuleRegistry {
    /// Register multiple modules at once
    func registerAll(_ moduleList: [Module]) throws {
        for module in moduleList {
            try register(module)
        }
    }
    
    /// Check if module is registered
    func isRegistered(_ name: String) -> Bool {
        return modules[name] != nil
    }
    
    /// Check if module is initialized
    func isInitialized(_ name: String) -> Bool {
        return initialized.contains(name)
    }
}
