import SwiftUI

struct ContentView: View {
    var body: some View {
        // PLACEHOLDER home: dev screens until Search (item 5) gives the app a
        // real home.
        TabView {
            DetectionDebugView()
                .tabItem { Label("Detection", systemImage: "camera.metering.spot") }
            SupabaseDebugView()
                .tabItem { Label("Supabase", systemImage: "cylinder.split.1x2") }
        }
    }
}

#Preview {
    ContentView()
}
