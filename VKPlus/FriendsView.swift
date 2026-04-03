import SwiftUI

struct FriendsView: View {
    @State private var friends: [VKUser] = []
    @State private var isLoading = false
    @State private var search = ""

    private var filtered: [VKUser] {
        guard !search.isEmpty else { return friends }
        return friends.filter { $0.fullName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.cyberBlue)
            } else {
                List(filtered) { friend in
                    FriendRow(user: friend)
                        .listRowBackground(Color.surface)
                        .listRowSeparatorTint(Color.divider)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .searchable(text: $search, prompt: "Поиск")
            }
        }
        .navigationTitle("Друзья (\(friends.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        friends = (try? await VKAPIClient.shared.getFriends()) ?? []
        isLoading = false
    }
}

private struct FriendRow: View {
    let user: VKUser
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(url: user.photo100, size: 44)
                if user.isOnline {
                    Circle().fill(Color.cyberAccent).frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.surface, lineWidth: 1.5))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.fullName)
                        .foregroundStyle(Color.onSurface)
                        .font(.system(size: 15, weight: .medium))
                    if user.verified == 1 {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.cyberBlue).font(.system(size: 12))
                    }
                }
                Text(user.isOnline ? "онлайн" : "не в сети")
                    .foregroundStyle(user.isOnline ? Color.cyberAccent : Color.onSurfaceMut)
                    .font(.system(size: 12))
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
