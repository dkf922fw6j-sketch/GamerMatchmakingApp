import SwiftUI
import FirebaseCore

@main
struct SwiftUI_calismaApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
