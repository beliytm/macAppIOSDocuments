import SwiftUI

// Drop-in replacement for @AppStorage when storing sensitive strings in Keychain.
// Usage: @KeychainStorage("gptApiKey") private var apiKey: String
@propertyWrapper
struct KeychainStorage: DynamicProperty {

    private let key: String
    @State private var cached: String

    init(_ key: String) {
        self.key = key
        // migrate old UserDefaults value if present
        KeychainHelper.migrateFromUserDefaults(udKey: key, keychainKey: key)
        let initial = KeychainHelper.load(forKey: key) ?? ""
        _cached = State(initialValue: initial)
    }

    var wrappedValue: String {
        get { cached }
        nonmutating set {
            cached = newValue
            if newValue.isEmpty {
                KeychainHelper.delete(forKey: key)
            } else {
                KeychainHelper.save(newValue, forKey: key)
            }
        }
    }

    var projectedValue: Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
