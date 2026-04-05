import SwiftUI

// MARK: - CommunitiesView
struct CommunitiesView: View {
    @StateObject private var vm = CommunitiesViewModel()
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                searchBar
                Divider().background(Color.divider)
                content
            }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) {
            ZStack(alignment: .leading) {
                GarlandView().frame(width: UIScreen.main.bounds.width).allowsHitTesting(false)
                PetView().frame(width: UIScreen.main.bounds.width).allowsHitTesting(false)
                ClockView().padding(.leading, 6)
            }
        }}
        .task { await vm.loadMyGroups() }
    }

    // MARK: Search bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.onSurfaceMut).font(.system(size: 15))
            TextField("Поиск сообществ...", text: $vm.query)
                .foregroundStyle(Color.onSurface).font(.system(size: 15))
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .focused($searchFocused)
                .onChange(of: vm.query) { _, v in vm.onQueryChange(v) }
            if !vm.query.isEmpty {
                Button { vm.query = ""; vm.searchMode = false; vm.searchResults = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.onSurfaceMut)
                }
            }
            if searchFocused || !vm.query.isEmpty {
                Button("Отмена") { vm.query = ""; searchFocused = false; vm.searchMode = false; vm.searchResults = [] }
                    .font(.system(size: 14)).foregroundStyle(Color.cyberBlue)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.surface)
        .animation(.easeInOut(duration: 0.2), value: searchFocused)
    }

    // MARK: Content
    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            Spacer(); ProgressView().tint(.cyberBlue); Spacer()
        } else if vm.searchMode {
            if vm.isSearching {
                Spacer(); ProgressView().tint(.cyberBlue); Spacer()
            } else if vm.searchResults.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundStyle(Color.onSurfaceMut)
                    Text("Ничего не найдено").foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
            } else {
                groupList(vm.searchResults)
            }
        } else {
            groupList(vm.myGroups)
        }
    }

    private func groupList(_ groups: [VKGroup]) -> some View {
        List(groups) { group in
            NavigationLink(destination: CommunityDetailView(group: group)) {
                GroupRow(group: group)
            }
            .listRowBackground(Color.surface)
            .listRowSeparatorTint(Color.divider)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await vm.loadMyGroups() }
    }
}

// MARK: - ViewModel
@MainActor
final class CommunitiesViewModel: ObservableObject {
    @Published var myGroups:     [VKGroup] = []
    @Published var searchResults:[VKGroup] = []
    @Published var query        = ""
    @Published var searchMode   = false
    @Published var isLoading    = false
    @Published var isSearching  = false

    private var searchTask: Task<Void, Never>? = nil

    func loadMyGroups() async {
        guard !isLoading else { return }
        isLoading = true
        myGroups = (try? await VKAPIClient.shared.getMyGroups()) ?? []
        isLoading = false
    }

    func onQueryChange(_ q: String) {
        searchTask?.cancel()
        if q.trimmingCharacters(in: .whitespaces).isEmpty {
            searchMode = false; searchResults = []; return
        }
        searchMode = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            isSearching = true
            searchResults = (try? await VKAPIClient.shared.searchGroups(query: q)) ?? []
            isSearching = false
        }
    }
}

// MARK: - GroupRow
struct GroupRow: View {
    let group: VKGroup
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: group.photoUrl, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(group.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.onSurface)
                        .lineLimit(1)
                    if group.isClosed == 1 {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.onSurfaceMut)
                    }
                }
                if !group.memberText.isEmpty {
                    Text(group.memberText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.onSurfaceMut)
                }
                if let act = group.activity, !act.isEmpty {
                    Text(act)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cyberBlue.opacity(0.8))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CommunityDetailView
struct CommunityDetailView: View {
    let group: VKGroup
    @State private var detail:      VKGroup? = nil
    @State private var posts:       [VKWallPost] = []
    @State private var profiles:    [Int: VKUser] = [:]
    @State private var groups:      [Int: VKGroup] = [:]
    @State private var isLoading    = true
    @State private var isMember:    Bool = false
    @State private var memberLoading = false

    private var displayGroup: VKGroup { detail ?? group }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.cyberBlue)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        Divider().background(Color.divider.opacity(0.5))
                        wallPosts
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(displayGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    // MARK: Header
    private var header: some View {
        VStack(spacing: 14) {
            // Avatar + name
            HStack(spacing: 14) {
                AvatarView(url: displayGroup.photoUrl, size: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(displayGroup.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.onSurface)
                        if displayGroup.isClosed == 1 {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.onSurfaceMut)
                        }
                    }
                    if !displayGroup.memberText.isEmpty {
                        Text(displayGroup.memberText)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.onSurfaceMut)
                    }
                    if let act = displayGroup.activity, !act.isEmpty {
                        Text(act)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cyberBlue.opacity(0.8))
                    }
                }
                Spacer()
            }

            // Description
            if let desc = displayGroup.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.onSurfaceMut)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Join/Leave button
            Button {
                Task { await toggleMembership() }
            } label: {
                HStack(spacing: 8) {
                    if memberLoading {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: isMember ? "person.badge.minus" : "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text(isMember ? "Выйти" : "Вступить")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(isMember ? Color.errorRed.opacity(0.7) : Color.cyberBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(memberLoading)
        }
        .padding(16)
        .background(Color.surface)
    }

    // MARK: Wall posts
    @ViewBuilder
    private var wallPosts: some View {
        if posts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text").font(.system(size: 36)).foregroundStyle(Color.onSurfaceMut)
                Text("Нет записей").foregroundStyle(Color.onSurfaceMut)
            }
            .padding(40)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(posts, id: \.uniqueKey) { post in
                    PostCard(
                        post: post,
                        authorName: authorName(post),
                        authorPhoto: authorPhoto(post),
                        onLike: {}
                    )
                }
            }
        }
    }

    // MARK: - Load
    private func load() async {
        isLoading = true
        async let detailTask  = VKAPIClient.shared.getGroupById(groupId: group.id)
        async let wallTask    = VKAPIClient.shared.getGroupWall(groupId: group.id, count: 30)
        let (d, wall) = await (try? detailTask, try? wallTask)
        detail   = d
        isMember = (d?.isMember ?? group.isMember) == 1
        if let wall {
            posts    = wall.items
            profiles = wall.profiles
            groups   = wall.groups
        }
        isLoading = false
    }

    private func toggleMembership() async {
        memberLoading = true
        do {
            if isMember { try await VKAPIClient.shared.leaveGroup(groupId: group.id) }
            else        { try await VKAPIClient.shared.joinGroup(groupId: group.id) }
            isMember.toggle()
        } catch {}
        memberLoading = false
    }

    private func authorName(_ p: VKWallPost) -> String {
        let id = p.authorId
        if id > 0 { return profiles[id]?.fullName ?? "Пользователь" }
        if id < 0 { return groups[-id]?.name ?? displayGroup.name }
        return displayGroup.name
    }
    private func authorPhoto(_ p: VKWallPost) -> String? {
        let id = p.authorId
        if id > 0 { return profiles[id]?.photo100 }
        if id < 0 { return groups[-id]?.photo100 }
        return displayGroup.photoUrl
    }
}
