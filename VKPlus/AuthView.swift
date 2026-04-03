import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onSuccess: () -> Void

    @State private var token        = ""
    @State private var tokenVisible = false
    @State private var cardOffset:  CGFloat = 50
    @State private var cardOpacity: Double  = 0

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            RadialGradient(
                colors: [Color.cyberBlue.opacity(0.07), Color.clear],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 56)

                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.cyberBlue.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(Color.cyberBlue.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 72, height: 72)
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        }

                        Text("Вход по токену")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.onSurface)

                        Text("Введите или вставьте\naccess token ВКонтакте")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.onSurfaceMut)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    Spacer().frame(height: 36)

                    // Card
                    VStack(spacing: 14) {

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Access Token")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.onSurfaceMut)

                            HStack(spacing: 8) {
                                Group {
                                    if tokenVisible {
                                        TextField("vk1.a.XXXXX...", text: $token)
                                    } else {
                                        SecureField("vk1.a.XXXXX...", text: $token)
                                    }
                                }
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color.onSurface)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.go)
                                .onSubmit { Task { await submit() } }

                                Button {
                                    if token.isEmpty {
                                        token = (UIPasteboard.general.string ?? "")
                                            .trimmingCharacters(in: .whitespacesAndNewlines)
                                    } else {
                                        token = ""
                                    }
                                } label: {
                                    Image(systemName: token.isEmpty ? "doc.on.clipboard" : "xmark.circle.fill")
                                        .foregroundStyle(token.isEmpty ? Color.cyberBlue : Color.onSurfaceMut)
                                        .frame(width: 28, height: 28)
                                }

                                Button { tokenVisible.toggle() } label: {
                                    Image(systemName: tokenVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(Color.onSurfaceMut)
                                        .frame(width: 28, height: 28)
                                }
                            }
                            .padding(13)
                            .background(Color.surfaceVar)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(token.isEmpty ? Color.divider : Color.cyberBlue.opacity(0.5), lineWidth: 1)
                            )
                        }

                        if let err = viewModel.error {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.errorRed)
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.errorRed)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button { Task { await submit() } } label: {
                            ZStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(Color.background)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text("Войти")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.background)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(token.isEmpty ? Color.cyberBlue.opacity(0.35) : Color.cyberBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(token.isEmpty || viewModel.isLoading)

                        Button {
                            guard let url = URL(string: "https://vkhost.github.io") else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            Text("Как получить токен? →")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.cyberBlue.opacity(0.7))
                        }
                    }
                    .padding(20)
                    .cyberCard()
                    .padding(.horizontal, 22)
                    .offset(y: cardOffset)
                    .opacity(cardOpacity)

                    Spacer().frame(height: 50)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.1)) {
                cardOffset = 0; cardOpacity = 1
            }
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuth in
            if isAuth { onSuccess() }
        }
    }

    private func submit() async { await viewModel.login(token: token) }
}
