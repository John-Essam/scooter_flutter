import Foundation

enum ConnectionPreferences {
    private static let key = "cardoo.scooter.lastPeripheralUUID"

    static var lastPeripheralUUID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let uuid = UUID(uuidString: raw) else { return nil }
            return uuid
        }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v.uuidString, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
