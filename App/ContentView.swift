import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SearchHomeView()
                .tabItem { Label("Home", systemImage: "magnifyingglass") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
            // Dev-only tabs below; removed before TestFlight (item 12).
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
