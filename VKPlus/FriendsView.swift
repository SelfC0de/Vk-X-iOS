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
                    NavigationLink(destination: FriendProfileView(user: friend)) {
                        FriendRow(user: friend)
                    }
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

struct FriendProfileView: View {
    let user: VKUser
    @State private var fullUser: VKUser?
    @State private var isLoading = false

    var display: VKUser { fullUser ?? user }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.cyberBlue)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero
                        ZStack(alignment: .bottom) {
                            LinearGradient(
                                colors: [Color.cyberBlue.opacity(0.20), Color.background],
                                startPoint: .top, endPoint: .bottom
                            ).frame(height: 180)

                            VStack(spacing: 12) {
                                AvatarView(url: display.photo200 ?? display.photo100, size: 88)
                                    .overlay(Circle().stroke(LinearGradient.cyberGrad, lineWidth: 2))
                                    .shadow(color: Color.cyberBlue.opacity(0.4), radius: 10)

                                HStack(spacing: 6) {
                                    Text(display.fullName)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Color.onSurface)
                                    if display.verified == 1 {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(Color.cyberBlue)
                                            .font(.system(size: 15))
                                    }
                                }

                                if let s = display.status, !s.isEmpty {
                                    Text(s).font(.system(size: 13))
                                        .foregroundStyle(Color.onSurfaceMut)
                                }

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(display.isOnline ? Color.cyberAccent : Color.onSurfaceMut)
                                        .frame(width: 8, height: 8)
                                    Text(display.isOnline ? "онлайн" : "не в сети")
                                        .font(.system(size: 12))
                                        .foregroundStyle(display.isOnline ? Color.cyberAccent : Color.onSurfaceMut)
                                }
                                .padding(.bottom, 20)
                            }
                        }

                        // Info card
                        VStack(spacing: 0) {
                            infoRow(icon: "number",      label: "ID",       value: "\(display.id)")
                            Divider().background(Color.divider).padding(.leading, 44)
                            infoRow(icon: "link",        label: "Страница", value: "vk.com/id\(display.id)")
                            if let city = display.city?.title {
                                Divider().background(Color.divider).padding(.leading, 44)
                                infoRow(icon: "mappin.and.ellipse", label: "Город", value: city)
                            }
                        }
                        .cyberCard().padding(.horizontal, 16).padding(.top, 16)

                        // Message button
                        NavigationLink(destination: ChatView(peerId: display.id, peerName: display.fullName, peerAvatar: display.photo100)) {
                            Label("Написать сообщение", systemImage: "message.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.background)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(Color.cyberBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16).padding(.top, 12)

                        Spacer().frame(height: 32)
                    }
                }
            }
        }
        .navigationTitle(display.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            isLoading = true
            fullUser = try? await VKAPIClient.shared.getUserById("\(user.id)")
            isLoading = false
        }
    }

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.cyberBlue).frame(width: 20)
            Text(label).foregroundStyle(Color.onSurfaceMut).font(.system(size: 13))
            Spacer()
            Text(value).foregroundStyle(Color.onSurface).font(.system(size: 13)).lineLimit(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
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
