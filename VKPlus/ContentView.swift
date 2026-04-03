import SwiftUI

enum AppPhase: Equatable { case splash, auth, main }

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @State private var phase: AppPhase = .splash

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            switch phase {
            case .splash:
                SplashView(onFinished: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        phase = authVM.isAuthenticated ? .main : .auth
                    }
                })
                .transition(.opacity)

            case .auth:
                AuthView(viewModel: authVM, onSuccess: {
                    withAnimation(.easeInOut(duration: 0.4)) { phase = .main }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))

            case .main:
                MainTabView()
                    .environmentObject(authVM)
                    .transition(.opacity)
            }
        }
    }
}
