import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        AnimatedMainTabView()
            .environmentObject(authVM)
    }
}
