import SwiftUI

// MARK: - VK link detector
struct VKLinkDetector {
    // Returns VK user id/screenname from any vk.com/vk.ru link or plain text
    static func extractScreenName(_ text: String) -> String? {
        let patterns = [
            #"https?://(?:www\.)?vk\.(?:com|ru)/([A-Za-z0-9_\.]+)"#,
            #"(?:^|[\s])vk\.(?:com|ru)/([A-Za-z0-9_\.]+)"#
        ]
        for pattern in patterns {
            if let r = text.range(of: pattern, options: .regularExpression) {
                let match = String(text[r])
                if let slashR = match.lastIndex(of: "/") {
                    let name = String(match[match.index(after: slashR)...])
                    if !name.isEmpty { return name }
                }
            }
        }
        return nil
    }
}

// MARK: - FriendsView
struct FriendsView: View {
    @State private var friends:       [VKUser] = []
    @State private var searchResults: [VKUser] = []
    @State private var isLoading      = false
    @State private var isSearching    = false
    @State private var search         = ""
    @State private var searchMode     = false
    @State private var searchTask:    Task<Void, Never>? = nil

    private var localFiltered: [VKUser] {
        guard !search.isEmpty else { return friends }
        return friends.filter { $0.fullName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.onSurfaceMut).font(.system(size: 15))
                        TextField("Поиск людей...", text: $search)
                            .foregroundStyle(Color.onSurface).font(.system(size: 15))
                            .autocorrectionDisabled()
                            .onChange(of: search) { _, v in onSearchChange(v) }
                        if !search.isEmpty {
                            Button { search = ""; searchMode = false; searchResults = [] } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.onSurfaceMut)
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.surfaceVar)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.surface)

                if isLoading {
                    Spacer(); ProgressView().tint(.cyberBlue); Spacer()
                } else if searchMode {
                    globalSearchList
                } else {
                    localList
                }
            }
        }
        .navigationTitle("Друзья (\(friends.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                VStack(spacing: 0) {
                    GarlandView()
                    PetView()
                    ClockView().padding(.leading, 4)
                }
                .frame(width: 200, alignment: .leading)
            } }
        .task { await load() }
    }

    private var localList: some View {
        List(localFiltered) { friend in
            NavigationLink(destination: FriendProfileView(user: friend)) {
                FriendRow(user: friend)
            }
            .listRowBackground(Color.surface)
            .listRowSeparatorTint(Color.divider)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var globalSearchList: some View {
        Group {
            if isSearching {
                VStack { Spacer(); ProgressView().tint(.cyberBlue); Spacer() }
            } else if searchResults.isEmpty && !search.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.slash").font(.system(size: 44)).foregroundStyle(Color.onSurfaceMut)
                    Text("Никого не найдено").foregroundStyle(Color.onSurfaceMut)
                    Spacer()
                }
            } else {
                List(searchResults) { user in
                    NavigationLink(destination: FriendProfileView(user: user)) {
                        FriendRow(user: user)
                    }
                    .listRowBackground(Color.surface)
                    .listRowSeparatorTint(Color.divider)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func onSearchChange(_ q: String) {
        searchTask?.cancel()
        guard !q.isEmpty else { searchMode = false; searchResults = []; return }
        searchMode = true

        // Check if it's a VK link
        if let name = VKLinkDetector.extractScreenName(q) {
            searchTask = Task {
                isSearching = true
                if let userId = try? await VKAPIClient.shared.resolveScreenName(name),
                   let users = try? await VKAPIClient.shared.getUsers(ids: "\(userId)") {
                    if !Task.isCancelled { searchResults = users }
                }
                isSearching = false
            }
            return
        }

        // Global people search with debounce
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { isSearching = false; return }
            isSearching = true
            do {
                let results = try await VKAPIClient.shared.searchUsers(query: q)
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                // search failed silently
            }
            isSearching = false
        }
    }

    private func load() async {
        isLoading = true
        friends = (try? await VKAPIClient.shared.getFriends()) ?? []
        isLoading = false
    }
}

// MARK: - FriendProfileView
struct FriendProfileView: View {
    let user: VKUser
    @State private var fullUser: VKUser?
    @State private var isLoading = false
    @State private var verificationInfo: VKVerificationInfo? = nil
    @ObservedObject private var settings = SettingsStore.shared

    var display: VKUser { fullUser ?? user }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if isLoading { ProgressView().tint(.cyberBlue) }
            else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ZStack(alignment: .bottom) {
                            LinearGradient(colors: [Color.cyberBlue.opacity(0.20), Color.background],
                                           startPoint: .top, endPoint: .bottom).frame(height: 180)
                            VStack(spacing: 12) {
                                AvatarView(url: display.photo200 ?? display.photo100, size: 88)
                                    .overlay(Circle().stroke(LinearGradient.cyberGrad, lineWidth: 2))
                                    .shadow(color: Color.cyberBlue.opacity(0.4), radius: 10)
                                HStack(spacing: 6) {
                                    Text(display.fullName).font(.system(size: 20, weight: .bold)).foregroundStyle(Color.onSurface)
                                    if display.verified == 1 {
                                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.cyberBlue).font(.system(size: 15))
                                    }
                                }
                                if let s = display.status, !s.isEmpty {
                                    Text(s).font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                                }
                                HStack(spacing: 6) {
                                    Circle().fill(display.isOnline ? Color.cyberAccent : Color.onSurfaceMut).frame(width: 8, height: 8)
                                    Text(display.isOnline ? "онлайн" : "не в сети")
                                        .font(.system(size: 12))
                                        .foregroundStyle(display.isOnline ? Color.cyberAccent : Color.onSurfaceMut)
                                }
                                .padding(.bottom, 20)
                            }
                        }

                        VStack(spacing: 0) {
                            infoRow(icon: "number", label: "ID", value: "\(display.id)")
                            Divider().background(Color.divider).padding(.leading, 44)
                            infoRow(icon: "link", label: "Страница", value: "vk.com/id\(display.id)")
                            if let city = display.city?.title {
                                Divider().background(Color.divider).padding(.leading, 44)
                                infoRow(icon: "mappin.and.ellipse", label: "Город", value: city)
                            }
                            if settings.verifyChecker {
                                Divider().background(Color.divider).padding(.leading, 44)
                                VerificationRowFetched(
                                    user: display,
                                    fetchedInfo: verificationInfo,
                                    fakeVerif: false
                                )
                            }
                        }
                        .cyberCard().padding(.horizontal, 16).padding(.top, 16)

                        HStack(spacing: 10) {
                            NavigationLink(destination: ChatView(peerId: display.id, peerName: display.fullName, peerAvatar: display.photo100)) {
                                Label("Написать", systemImage: "message.fill")
                                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.background)
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(Color.cyberBlue)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Button {
                                let link = "https://vk.com/id\(display.id)"
                                UIPasteboard.general.string = link
                                ToastManager.shared.show("Ссылка скопирована", icon: "link", style: .success)
                            } label: {
                                Image(systemName: "link")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.cyberBlue)
                                    .frame(width: 50, height: 50)
                                    .background(Color.cyberBlue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyberBlue.opacity(0.3), lineWidth: 1))
                            }
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
            async let u = VKAPIClient.shared.getUserById("\(user.id)")
            async let v = SettingsStore.shared.verifyChecker
                ? VKAPIClient.shared.getUserVerification(userId: user.id)
                : nil
            fullUser = try? await u
            verificationInfo = try? await v
            isLoading = false
            SettingsStore.shared.addProfileHistory(user.id)
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

// MARK: - FriendRow
struct FriendRow: View {
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
                    Text(user.fullName).foregroundStyle(Color.onSurface)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    VerificationBadgesInline(user: user)
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

// MARK: - Inline verification badges (for list rows and headers)
struct VerificationBadgesInline: View {
    let user: VKUser
    private var isVKVerified: Bool { user.verified == 1 }
    private var verifications: [VKVerification] {
        (user.verificationInfo?.verifications ?? []).sorted { ($0.priority ?? 99) < ($1.priority ?? 99) }
    }

    var body: some View {
        let hasAny = isVKVerified || !verifications.isEmpty
        if hasAny {
            HStack(spacing: 3) {
                if isVKVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(r:0x1D,g:0xA1,b:0xF2))
                }
                ForEach(verifications, id: \.type) { v in
                    ServiceFaviconView(type: v.type)
                        .frame(width: 14, height: 14)
                }
            }
        }
    }
}

// MARK: - VerificationRow with fetched override
struct VerificationRowFetched: View {
    let user: VKUser
    let fetchedInfo: VKVerificationInfo?
    let fakeVerif: Bool

    // Use fetched info if available, else fall back to user.verificationInfo
    private var effectiveInfo: VKVerificationInfo? { fetchedInfo ?? user.verificationInfo }

    private var isVKVerified: Bool { fakeVerif || user.verified == 1 }
    private var verifications: [VKVerification] {
        (effectiveInfo?.verifications ?? []).sorted { ($0.priority ?? 99) < ($1.priority ?? 99) }
    }
    private var hasAny: Bool { isVKVerified || !verifications.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hasAny ? Color(r:0x1D,g:0xA1,b:0xF2).opacity(0.15) : Color.surfaceVar)
                        .frame(width: 28, height: 28)
                    Image(systemName: hasAny ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(.system(size: 14))
                        .foregroundStyle(hasAny ? Color(r:0x1D,g:0xA1,b:0xF2) : Color.onSurfaceMut)
                }
                Text("Верификация")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.onSurface)
                Spacer()
                if !hasAny {
                    Text("Отсутствует")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.onSurfaceMut)
                } else {
                    HStack(spacing: 5) {
                        if isVKVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(r:0x1D,g:0xA1,b:0xF2))
                        }
                        ForEach(verifications, id: \.type) { v in
                            ServiceFaviconView(type: v.type)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            if !verifications.isEmpty {
                let vNames: [String: String] = [
                    "gosuslugi": "Госуслуги", "alfa": "Альфа-Банк",
                    "tinkoff": "Т-Банк", "sber": "СберБанк", "vtb": "ВТБ"
                ]
                Divider().background(Color.divider).padding(.leading, 56)
                VStack(spacing: 0) {
                    ForEach(Array(verifications.enumerated()), id: \.element.type) { idx, v in
                        HStack(spacing: 12) {
                            ServiceFaviconView(type: v.type).frame(width: 28)
                            Text(vNames[v.type] ?? v.name ?? v.type)
                                .font(.system(size: 13)).foregroundStyle(Color.onSurface)
                            Spacer()
                            Text("Подтверждено")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(r:0x52,g:0xC4,b:0x1A))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(r:0x52,g:0xC4,b:0x1A).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        if idx < verifications.count - 1 {
                            Divider().background(Color.divider).padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }
}
