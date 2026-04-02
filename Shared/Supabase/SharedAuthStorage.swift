import Supabase
import Foundation

/// Stores Supabase auth tokens in the shared App Group UserDefaults so both
/// the main app and the widget extension read the same session.
struct SharedAuthStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {
        SharedDataStore.sharedDefaults.set(value, forKey: key)
    }

    func retrieve(key: String) throws -> Data? {
        SharedDataStore.sharedDefaults.data(forKey: key)
    }

    func remove(key: String) throws {
        SharedDataStore.sharedDefaults.removeObject(forKey: key)
    }
}
