import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var user: VKUser?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.cyberBlue)
            } else if let u = user {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 14) {
                            AvatarView(url: u.photo200 ?? u.photo100, size: 96)
                                .overlay(Circle().stroke(Color.cyberBlue, lineWidth: 2))

                            HStack(spacing: 6) {
                                Text(u.fullName)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.onSurface)
                                if u.verified == 1 {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Color.cyberBlue).font(.system(size: 16))
                                }
                            }

                            if let s = u.status, !s.isEmpty {
                                Text(s).foregroundStyle(Color.onSurfaceMut).font(.system(size: 14))
                            }

                            Text("vk.com/id\(u.id)")
                                .foregroundStyle(Color.cyberBlue).font(.system(size: 13))
                        }
                        .padding(.top, 24)

                        VStack(spacing: 0) {
                            ProfileInfoRow(icon: "number", label: "ID", value: "\(u.id)")
                            Divider().background(Color.divider).padding(.leading, 44)
                            ProfileInfoRow(icon: "link", label: "Страница", value: "vk.com/id\(u.id)")
                            Divider().background(Color.divider).padding(.leading, 44)
                            ProfileInfoRow(
                                icon:  u.isOnline ? "circle.fill" : "circle",
                                label: "Статус",
                                value: u.isOnline ? "Онлайн" : "Не в сети",
                                valueColor: u.isOnline ? Color.cyberAccent : Color.onSurfaceMut
                            )
                        }
                        .cyberCard()
                        .padding(.horizontal, 16)

                        Button { authVM.logout() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Выйти из аккаунта").font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(Color.errorRed)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Color.errorRed.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 20)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 44)).foregroundStyle(Color.onSurfaceMut)
                    Text("Не удалось загрузить профиль").foregroundStyle(Color.onSurfaceMut)
                    Button("Повторить") { Task { await load() } }
                        .foregroundStyle(Color.cyberBlue)
                }
            }
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        user = try? await VKAPIClient.shared.getProfile()
        isLoading = false
    }
}

private struct ProfileInfoRow: View {
    let icon: String; let label: String; let value: String
    var valueColor: Color = Color.onSurface
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.cyberBlue).frame(width: 20)
            Text(label).foregroundStyle(Color.onSurfaceMut).font(.system(size: 13))
            Spacer()
            Text(value).foregroundStyle(valueColor).font(.system(size: 13))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}
