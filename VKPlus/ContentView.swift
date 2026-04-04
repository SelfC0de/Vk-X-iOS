import SwiftUI

enum AppPhase: Equatable { case splash, auth, main }

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @State private var phase: AppPhase = .splash
    @State private var showMain = false

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            // Main tab always underneath — revealed by split
            if showMain || phase == .main {
                MainTabView()
                    .environmentObject(authVM)
                    .zIndex(0)
            }

            switch phase {
            case .splash:
                SplashView(
                    onFinished: {
                        if authVM.isAuthenticated {
                            // Split already happened — just clear splash
                            withAnimation(.easeInOut(duration: 0.1)) {
                                phase = .main
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                phase = .auth
                            }
                        }
                    },
                    isAuthenticated: authVM.isAuthenticated
                )
                .zIndex(1)
                .transition(.opacity)
                .onAppear {
                    // Pre-load main if already auth so it's ready under the split
                    if authVM.isAuthenticated { showMain = true }
                }

            case .auth:
                AuthView(viewModel: authVM, onSuccess: {
                    withAnimation(.easeInOut(duration: 0.4)) { phase = .main }
                })
                .zIndex(1)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))

            case .main:
                EmptyView()
            }
        }
    }
}
