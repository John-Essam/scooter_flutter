import SwiftUI

@main
struct ScooterAppApp: App {
    init() {
        // Touch the singleton on launch so CBCentralManager initialises early — this lets
        // state preservation/restoration deliver willRestoreState before any view appears.
        _ = BleManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
