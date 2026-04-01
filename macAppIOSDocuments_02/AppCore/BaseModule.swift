// BaseModule.swift
// Базовый протокол для всех модулей приложения (GPT-MODULAR v3.6)
import Foundation
import SwiftUI

// MARK: - Module Result

enum ModuleResult {
    case success(Any?)
    case failure(Error)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Module Protocol (GPT-MODULAR Contract)

/// Every module MUST implement this protocol
/// - getName: unique identifier
/// - initialize: setup only, NO business logic
/// - execute: main work, NO global state mutation
/// - cleanup: teardown, safe to call multiple times
/// - getDependencies: required modules (or [])
protocol Module: AnyObject {
    /// Unique module identifier (PascalCase)
    var name: String { get }
    
    /// Module display name for UI
    var displayName: String { get }
    
    /// SF Symbol icon name
    var icon: String { get }
    
    /// Required module dependencies (names)
    var dependencies: [String] { get }
    
    /// Module initialization - setup only, NO business logic
    func initialize() async throws
    
    /// Main module work - NO global state mutation
    func execute() async -> ModuleResult
    
    /// Cleanup resources - safe to call multiple times (idempotent)
    func cleanup()
    
    /// Get SwiftUI view for this module
    func getView() -> AnyView
}

// MARK: - Base Module Implementation

/// Base class providing default implementations
class BaseModule: Module {
    let name: String
    let displayName: String
    let icon: String
    var dependencies: [String] = []
    
    private var isInitialized = false
    
    init(name: String, displayName: String, icon: String, dependencies: [String] = []) {
        self.name = name
        self.displayName = displayName
        self.icon = icon
        self.dependencies = dependencies
    }
    
    func initialize() async throws {
        guard !isInitialized else {
            warn("Module already initialized: \(name)", "initialize()", [:])
            return
        }
        isInitialized = true
        info("Module initialized", "initialize()", [:])
    }
    
    func execute() async -> ModuleResult {
        guard isInitialized else {
            let error = ModuleError.notInitialized(name)
            log(error, "execute()", ["isInitialized": isInitialized])
            return .failure(error)
        }
        return .success(nil)
    }
    
    func cleanup() {
        isInitialized = false
        info("Module cleaned up: \(name)", "cleanup()", [:])
    }
    
    func getView() -> AnyView {
        AnyView(EmptyView())
    }
}

// MARK: - Module Errors

enum ModuleError: LocalizedError {
    case notInitialized(String)
    case dependencyMissing(String, String)
    case circularDependency(String)
    case alreadyRegistered(String)
    case initializationFailed(String, Error)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized(let name):
            return "Module '\(name)' is not initialized"
        case .dependencyMissing(let module, let dependency):
            return "Module '\(module)' requires '\(dependency)' which is not registered"
        case .circularDependency(let path):
            return "Circular dependency detected: \(path)"
        case .alreadyRegistered(let name):
            return "Module '\(name)' is already registered"
        case .initializationFailed(let name, let error):
            return "Module '\(name)' failed to initialize: \(error.localizedDescription)"
        }
    }
}

// MARK: - Legacy Protocol Support

/// Legacy protocol for backward compatibility
protocol BaseModuleLegacy {
    var moduleName: String { get }
    var icon: String { get }
    func getView() -> AnyView
}
