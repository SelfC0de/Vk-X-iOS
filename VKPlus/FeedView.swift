import SwiftUI

// MARK: - URL helper
private func resolveURL(_ raw: String) -> URL? {
    var str = raw
    if SettingsStore.shared.bypassLinks,
       (str.contains("vk.com/away") || str.contains("vk.cc/")),
       let comps = URLComponents(string: str),
       let to = comps.queryItems?.first(where: { $0.name == "to" })?.value,
       let decoded = to.removingPercentEncoding { str = decoded }
    return URL(string: str)
}

// MARK: - ViewModel
@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts:        [VKWallPost] = []
    @Published var profiles:     [Int: VKUser]  = [:]
    @Published var groups:       [Int: VKGroup]  = [:]
    @Published var isLoading     = false
    @Published var isRefreshing  = false
    @Published var isLoadingMore = false
    @Published var error:        String? = nil
    @Published var nextFrom:     String? = nil

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil
        do {
            let page = try await VKAPIClient.shared.getNewsfeed()
            posts = page.items; profiles = page.profiles
            groups = page.groups; nextFrom = page.nextFrom
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func refresh() async {
        isRefreshing = true; error = nil
        do {
            let page = try await VKAPIClient.shared.getNewsfeed()
            posts = page.items; profiles = page.profiles
            groups = page.groups; nextFrom = page.nextFrom
        } catch { self.error = error.localizedDescription }
        isRefreshing = false
    }

    func loadMore() async {
        guard !isLoadingMore, let nf = nextFrom else { return }
        isLoadingMore = true
        do {
            let page = try await VKAPIClient.shared.getNewsfeed(startFrom: nf)
            let existing = Set(posts.map { $0.uniqueKey })
            let fresh = page.items.filter { !existing.contains($0.uniqueKey) }
            posts += fresh
            profiles.merge(page.profiles) { _, n in n }
            groups.merge(page.groups)     { _, n in n }
            nextFrom = page.nextFrom
        } catch {}
        isLoadingMore = false
    }

    func toggleLike(post: VKWallPost) async {
        guard let idx = posts.firstIndex(where: { $0.id == post.id && $0.authorId == post.authorId }) else { return }
        let wasLiked = posts[idx].likes?.isLiked == true
        let cur      = posts[idx].likes?.count ?? 0
        posts[idx].likes = VKLikesObj(count: wasLiked ? max(0, cur-1) : cur+1,
                                       userLikes: wasLiked ? nil : 1)
        do {
            let oid = post.postOwnerId
            if wasLiked { _ = try await VKAPIClient.shared.deleteLike(ownerId: oid, itemId: post.id) }
            else        { _ = try await VKAPIClient.shared.addLike(ownerId: oid, itemId: post.id) }
        } catch { posts[idx].likes = post.likes }
    }

    func authorName(for post: VKWallPost) -> String {
        let id = post.authorId
        if id > 0  { return profiles[id]?.fullName ?? "Пользователь" }
        if id < 0  { return groups[-id]?.name ?? "Сообщество" }
        return "VK"
    }
    func authorPhoto(for post: VKWallPost) -> String? {
        let id = post.authorId
        if id > 0 { return profiles[id]?.photo100 }
        if id < 0 { return groups[-id]?.photo100 }
        return nil
    }
}

// MARK: - FeedView
struct FeedView: View {
    @StateObject private var vm = FeedViewModel()

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.posts.isEmpty {
                    ProgressView().tint(.cyberBlue)
                } else if let err = vm.error, vm.posts.isEmpty {
                    errorView(err)
                } else {
                    feedList
                }
            }
        }
        .navigationTitle("Лента")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                VStack(spacing: 0) {
                    GarlandView()
                    PetView()
                    ClockView().padding(.leading, 4)
                }
                .frame(width: 200, alignment: .leading)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    if vm.isRefreshing {
                        ProgressView().tint(.cyberBlue)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.cyberBlue)
                    }
                }
                .disabled(vm.isRefreshing)
            }
        }
        .task { await vm.load() }
    }

    private var feedList: some View {
        List {
            ForEach(vm.posts, id: \.uniqueKey) { post in
                PostCard(
                    post:        post,
                    authorName:  vm.authorName(for: post),
                    authorPhoto: vm.authorPhoto(for: post),
                    onLike:      { Task { await vm.toggleLike(post: post) } }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.background)
                .listRowSeparator(.hidden)
                .onAppear {
                    if post.id == vm.posts.suffix(5).first?.id {
                        Task { await vm.loadMore() }
                    }
                }
            }
            if vm.isLoadingMore {
                HStack { Spacer(); ProgressView().tint(.cyberBlue).padding(16); Spacer() }
                    .listRowBackground(Color.background)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // Native iOS pull-to-refresh
        .refreshable { await vm.refresh() }
    }

    @ViewBuilder
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40)).foregroundStyle(Color.errorRed)
            Text("Ошибка загрузки")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.errorRed)
            Text(msg).font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { Task { await vm.load() } } label: {
                Text("Повторить").foregroundStyle(Color.background)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.cyberBlue).clipShape(Capsule())
            }
        }
    }
}

// MARK: - PostCard
private struct PostCard: View {
    let post:        VKWallPost
    let authorName:  String
    let authorPhoto: String?
    let onLike:      () -> Void

    private var dateStr: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "ru_RU"); df.dateFormat = "d MMM · HH:mm"
        return df.string(from: Date(timeIntervalSince1970: TimeInterval(post.date)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author
            HStack(spacing: 10) {
                AvatarView(url: authorPhoto, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(authorName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.onSurface)
                    Text(dateStr).font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.top, 12)

            // Text
            if !post.text.isEmpty {
                ExpandableText(text: post.text)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Attachments
            if let att = post.attachments, !att.isEmpty {
                let photos = att.filter { $0.type == "photo" }.compactMap { $0.photo }
                let links  = att.filter { $0.type == "link"  }.compactMap { $0.link }
                if !photos.isEmpty {
                    PhotoGrid(photos: photos).padding(.horizontal, 14).padding(.top, 8)
                }
                ForEach(links.indices, id: \.self) { i in
                    LinkPreview(link: links[i]).padding(.horizontal, 14).padding(.top, 6)
                }
            }

            // Actions
            HStack(spacing: 20) {
                AnimatedLikeButton(isLiked: post.likes?.isLiked == true,
                                   count: post.likes?.count ?? 0,
                                   onTap: onLike)

                HStack(spacing: 4) {
                    Image(systemName: "bubble.left").font(.system(size: 15)).foregroundStyle(Color.onSurfaceMut)
                    if let c = post.comments?.count, c > 0 {
                        Text("\(c)").font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath").font(.system(size: 15)).foregroundStyle(Color.onSurfaceMut)
                    if let c = post.reposts?.count, c > 0 {
                        Text("\(c)").font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                    }
                }
                Spacer()
                if let v = post.views?.count, v > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "eye").font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                        Text(fmtViews(v)).font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider().background(Color.divider.opacity(0.4))
        }
        .background(Color.background)
    }

    private func fmtViews(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}

// MARK: - ExpandableText
private struct ExpandableText: View {
    let text: String
    @State private var expanded = false
    private let limit = 300
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let long  = text.count > limit
            let shown = !expanded && long ? String(text.prefix(limit)) + "…" : text
            Text(shown)
                .font(.system(size: 14))
                .foregroundStyle(Color.onSurface)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if long {
                Button { withAnimation { expanded.toggle() } } label: {
                    Text(expanded ? "Скрыть" : "Показать полностью")
                        .font(.system(size: 13)).foregroundStyle(Color.cyberBlue)
                }.buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - PhotoGrid
private struct PhotoGrid: View {
    let photos: [VKPhoto]
    var body: some View {
        let count = min(photos.count, 4)
        Group {
            if count == 1 { singlePhoto(photos[0]) }
            else if count == 2 {
                HStack(spacing: 4) { ForEach(0..<2,id:\.self) { tilePhoto(photos[$0]) } }.frame(height: 200)
            } else if count == 3 {
                HStack(spacing: 4) {
                    singlePhoto(photos[0]).frame(maxWidth: .infinity)
                    VStack(spacing: 4) { ForEach(1..<3,id:\.self) { tilePhoto(photos[$0]) } }.frame(maxWidth: .infinity)
                }.frame(height: 240)
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 4) { ForEach(0..<2,id:\.self) { tilePhoto(photos[$0]) } }
                    HStack(spacing: 4) { ForEach(2..<4,id:\.self) { tilePhoto(photos[$0]) } }
                }.frame(height: 280)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    @ViewBuilder private func singlePhoto(_ p: VKPhoto) -> some View {
        if let url = p.maxUrl.flatMap(URL.init) {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase { img.resizable().scaledToFill() }
                else { Color.surfaceVar }
            }.frame(maxWidth:.infinity).frame(height:280).clipped()
        }
    }
    @ViewBuilder private func tilePhoto(_ p: VKPhoto) -> some View {
        if let url = p.maxUrl.flatMap(URL.init) {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase { img.resizable().scaledToFill() }
                else { Color.surfaceVar }
            }.frame(maxWidth:.infinity,maxHeight:.infinity).clipped()
        }
    }
}

// MARK: - LinkPreview
private struct LinkPreview: View {
    let link: VKLinkAttach
    var body: some View {
        Button {
            guard let url = resolveURL(link.url) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "link").font(.system(size: 14)).foregroundStyle(Color.cyberBlue).frame(width: 14)
                VStack(alignment: .leading, spacing: 2) {
                    if let t = link.title, !t.isEmpty {
                        Text(t).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.onSurface).lineLimit(1)
                    }
                    Text(link.url).font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut).lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
            }
            .padding(10).background(Color.surfaceVar).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 0.5))
        }.buttonStyle(.plain)
    }
}
