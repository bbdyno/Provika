import SwiftUI

@main
struct ProvikaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Provika")
            .font(.largeTitle)
    }
}
