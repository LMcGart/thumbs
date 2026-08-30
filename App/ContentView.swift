import SwiftUI

struct ContentView: View {
    var body: some View {
        // Keyboard dismissal, app-wide: any scroll drag closes it, and a Done
        // accessory above the keyboard closes it explicitly.
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
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
