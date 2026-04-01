// Logger.swift
// GPT-оптимизированный логгер {f, e, c, ctx}
import Foundation

// MARK: - Log Entry

struct LogEntry: Codable {
    let f: String      // file:line (WHERE)
    let e: String      // error message (WHAT)
    let c: String      // code line (WHICH)
    let ctx: String?   // context (WHY)
    let timestamp: Date
    let level: LogLevel
    let module: LogModule
}

enum LogLevel: String, Codable {
    case error
    case warn
    case info
}

enum LogModule: String, Codable {
    case system      // Системные логи
    case translation // Логи перевода/повторений
}

// MARK: - Logger

final class GPTLogger {
    static let shared = GPTLogger()
    
    private var entries: [LogEntry] = []
    private let maxEntries = 100
    private let lock = NSLock()
    
    #if DEBUG
    private var isEnabled = true
    #else
    private var isEnabled = false
    #endif
    
    private init() {}
    
    // MARK: - Public API
    
    /// Main error logging function
    func log(
        _ error: Error,
        _ code: String,
        _ context: [String: Any] = [:],
        module: LogModule = .system,
        file: String = #file,
        line: Int = #line
    ) {
        logInternal(
            message: error.localizedDescription,
            code: code,
            context: context,
            level: .error,
            module: module,
            file: file,
            line: line
        )
    }
    
    /// Warning logging
    func warn(
        _ message: String,
        _ code: String,
        _ context: [String: Any] = [:],
        module: LogModule = .system,
        file: String = #file,
        line: Int = #line
    ) {
        logInternal(
            message: message,
            code: code,
            context: context,
            level: .warn,
            module: module,
            file: file,
            line: line
        )
    }
    
    /// Info logging
    func info(
        _ message: String,
        _ code: String,
        _ context: [String: Any] = [:],
        module: LogModule = .system,
        file: String = #file,
        line: Int = #line
    ) {
        logInternal(
            message: message,
            code: code,
            context: context,
            level: .info,
            module: module,
            file: file,
            line: line
        )
    }
    
    // MARK: - Filtered Logs
    
    func getLogs(module: LogModule? = nil) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        if let module = module {
            return entries.filter { $0.module == module }
        }
        return entries
    }
    
    func exportLogs(module: LogModule? = nil) -> String {
        let filteredEntries: [LogEntry]
        lock.lock()
        if let module = module {
            filteredEntries = entries.filter { $0.module == module }
        } else {
            filteredEntries = entries
        }
        lock.unlock()
        
        return filteredEntries.map { entry in
            var dict: [String: Any] = [
                "f": entry.f,
                "e": entry.e,
                "c": entry.c
            ]
            if let ctx = entry.ctx {
                dict["ctx"] = ctx
            }
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "{}"
        }.joined(separator: "\n")
    }
    
    // MARK: - Log Management
    
    func getLogsCount(module: LogModule? = nil) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if let module = module {
            return entries.filter { $0.module == module }.count
        }
        return entries.count
    }
    
    func clearLogs(module: LogModule? = nil) {
        lock.lock()
        defer { lock.unlock() }
        if let module = module {
            entries.removeAll { $0.module == module }
        } else {
            entries.removeAll()
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    // MARK: - Private
    
    private func logInternal(
        message: String,
        code: String,
        context: [String: Any],
        level: LogLevel,
        module: LogModule,
        file: String,
        line: Int
    ) {
        let fileName = (file as NSString).lastPathComponent
        
        // Extract only problematic values
        let problematicContext = context.filter { _, value in
            if value is NSNull { return true }
            if let optional = value as? OptionalProtocol, optional.isNil { return true }
            if let str = value as? String, str.isEmpty { return true }
            if let arr = value as? [Any], arr.isEmpty { return true }
            if let num = value as? Double, num.isNaN { return true }
            return false
        }
        
        let ctx: String? = problematicContext.isEmpty ? nil : problematicContext.map { key, value in
            "\(key)=\(formatValue(value))"
        }.joined(separator: ",")
        
        let entry = LogEntry(
            f: "\(fileName):\(line)",
            e: message,
            c: code,
            ctx: ctx,
            timestamp: Date(),
            level: level,
            module: module
        )
        
        // Store entry synchronously with lock (skip duplicates)
        lock.lock()
        let isDuplicate = entries.contains { $0.f == entry.f && $0.e == entry.e && $0.c == entry.c }
        if !isDuplicate {
            entries.append(entry)
            if entries.count > maxEntries {
                entries.removeFirst()
            }
        }
        lock.unlock()
        
        #if DEBUG
        // Only print errors to console (no duplicates)
        if isEnabled && level == .error && !isDuplicate {
            var output: [String: Any] = ["f": entry.f, "e": entry.e, "c": entry.c]
            if let ctx = entry.ctx {
                output["ctx"] = ctx
            }
            
            if let data = try? JSONSerialization.data(withJSONObject: output, options: []),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        }
        #endif
    }
    
    private func formatValue(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let optional = value as? OptionalProtocol, optional.isNil { return "nil" }
        if let arr = value as? [Any], arr.isEmpty { return "[]" }
        if let num = value as? Double, num.isNaN { return "NaN" }
        return String(describing: value)
    }
}

// MARK: - Optional Protocol Helper

private protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool { self == nil }
}

// MARK: - Global Functions

/// GPT-optimized error logging
func log(
    _ error: Error,
    _ code: String,
    _ context: [String: Any] = [:],
    module: LogModule = .system,
    file: String = #file,
    line: Int = #line
) {
    GPTLogger.shared.log(error, code, context, module: module, file: file, line: line)
}

/// GPT-optimized warning logging
func warn(
    _ message: String,
    _ code: String,
    _ context: [String: Any] = [:],
    module: LogModule = .system,
    file: String = #file,
    line: Int = #line
) {
    GPTLogger.shared.warn(message, code, context, module: module, file: file, line: line)
}

/// GPT-optimized info logging
func info(
    _ message: String,
    _ code: String,
    _ context: [String: Any] = [:],
    module: LogModule = .system,
    file: String = #file,
    line: Int = #line
) {
    GPTLogger.shared.info(message, code, context, module: module, file: file, line: line)
}
