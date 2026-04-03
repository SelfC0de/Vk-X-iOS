import SwiftUI

struct RemoveBannedView: View {
    @State private var friends: [VKUser] = []
    @State private var banned:  [VKUser] = []
    @State private var isScanning  = false
    @State private var isRemoving  = false
    @State private var removed     = 0
    @State private var done        = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Header card
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.minus")
                            .font(.system(size: 40)).foregroundStyle(Color.errorRed)
                        Text("Remove Banned Users")
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(Color.onSurface)
                        Text("Удаляет удалённые и заблокированные аккаунты из списка друзей")
                            .font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20).cyberCard()

                    if isScanning {
                        statusCard(icon: "arrow.clockwise", color: .cyberBlue,
                                   text: "Сканирование списка друзей...")
                    } else if isRemoving {
                        statusCard(icon: "trash", color: .errorRed,
                                   text: "Удаляем... \(removed)/\(banned.count + removed)")
                    } else if done && banned.isEmpty {
                        statusCard(icon: "checkmark.circle.fill", color: Color(r:0x4C,g:0xAF,b:0x50),
                                   text: removed > 0 ? "Удалено \(removed) аккаунтов" : "Список чист — удалённых нет")
                        Button("Сканировать снова") { resetState() }
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.cyberBlue)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Color.cyberBlue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else if !banned.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Найдено \(banned.count) удалённых:")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.errorRed)
                            ForEach(banned.prefix(5)) { user in
                                HStack(spacing: 10) {
                                    AvatarView(url: user.photo100, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.fullName).foregroundStyle(Color.onSurfaceMut).font(.system(size: 13))
                                        Text(user.deactivated == "banned" ? "заблокирован ВК" : "удалён")
                                            .font(.system(size: 11)).foregroundStyle(Color.errorRed)
                                    }
                                }
                            }
                            if banned.count > 5 {
                                Text("...и ещё \(banned.count - 5)").font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                            }
                        }
                        .padding(16).cyberCard()

                        Button { Task { await removeAll() } } label: {
                            Label("Удалить всех (\(banned.count))", systemImage: "trash")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.onSurface)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(Color.errorRed).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        Button { Task { await scan() } } label: {
                            Label("Сканировать", systemImage: "magnifyingglass")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.cyberBlue)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(Color.cyberBlue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    if let err = error {
                        Text(err).font(.system(size: 12)).foregroundStyle(Color.errorRed).multilineTextAlignment(.center)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Remove Banned").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func statusCard(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 20))
            Text(text).foregroundStyle(Color.onSurfaceMut).font(.system(size: 14))
        }
        .padding(16).cyberCard()
    }

    private func scan() async {
        isScanning = true; error = nil
        do {
            let all = try await VKAPIClient.shared.getFriendsWithStatus()
            banned = all.filter { $0.isBanned }
            done   = true
        } catch { self.error = error.localizedDescription }
        isScanning = false
    }

    private func removeAll() async {
        isRemoving = true; removed = 0
        let toRemove = banned
        for user in toRemove {
            _ = try? await VKAPIClient.shared.deleteFriend(userId: user.id)
            await MainActor.run { removed += 1; banned.removeAll { $0.id == user.id } }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        done = true; isRemoving = false
    }

    private func resetState() { banned = []; done = false; removed = 0; error = nil }
}
