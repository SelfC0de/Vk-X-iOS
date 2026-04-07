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
    private var lastPostTime:    Int    = 0   // unix timestamp of newest loaded post

    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil
        do {
            let page = try await VKAPIClient.shared.getNewsfeed()
            posts    = page.items
            profiles = page.profiles
            groups   = page.groups
            nextFrom = page.nextFrom
            lastPostTime = page.items.map { $0.date }.max() ?? 0
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func refresh() async {
        isRefreshing = true; error = nil
        do {
            // Use start_time = last known post time to fetch only newer posts
            let since = lastPostTime > 0 ? lastPostTime : nil
            let page = try await VKAPIClient.shared.getNewsfeed(startTime: since)
            profiles.merge(page.profiles) { _, n in n }
            groups.merge(page.groups)     { _, n in n }
            if !page.items.isEmpty {
                let existingKeys = Set(posts.map { $0.uniqueKey })
                let fresh = page.items.filter { !existingKeys.contains($0.uniqueKey) }
                if !fresh.isEmpty {
                    // Sort fresh by date descending before prepend
                    posts = fresh.sorted { $0.date > $1.date } + posts
                    let newMax = fresh.map { $0.date }.max() ?? lastPostTime
                    if newMax > lastPostTime { lastPostTime = newMax }
                }
            }
            // Update nextFrom only if we got a new cursor (pagination for loadMore)
            if let nf = page.nextFrom { nextFrom = nf }
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
// MARK: - FeedView
struct FeedView: View {
    @StateObject private var vm = FeedViewModel()

    @ObservedObject private var settings = SettingsStore.shared
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if let data = settings.feedBgImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.18)
            }
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ZStack(alignment: .leading) {
                    GarlandView()
                        .frame(width: UIScreen.main.bounds.width)
                        .allowsHitTesting(false)
                    PetView()
                        .frame(width: UIScreen.main.bounds.width)
                        .allowsHitTesting(false)
                    ClockView()
                        .padding(.leading, 6)
                }
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
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.background)
                .listRowSeparator(.hidden)
                .frame(maxWidth: .infinity, alignment: .leading)
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
struct PostCard: View {
    let post:        VKWallPost
    let authorName:  String
    let authorPhoto: String?
    let onLike:      () -> Void

    @State private var showPhotoViewer   = false
    @State private var photoViewerIndex  = 0
    @State private var showRepostSheet   = false
    @State private var showMediaForward  = false

    private var dateStr: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "ru_RU"); df.dateFormat = "d MMM · HH:mm"
        return df.string(from: Date(timeIntervalSince1970: TimeInterval(post.date)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author — tappable, opens community page if group
            NavigationLink(destination: authorDestination) {
                HStack(spacing: 10) {
                    AvatarView(url: authorPhoto, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(authorName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.onSurface)
                        Text(dateStr).font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.top, 12)

            // Text — selectable, links clickable
            if !post.text.isEmpty {
                ExpandableText(text: post.text)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Attachments
            if let att = post.attachments, !att.isEmpty {
                let photos = att.filter { $0.type == "photo" }.compactMap { $0.photo }
                let videos = att.filter { $0.type == "video" }.compactMap { $0.video }
                let links  = att.filter { $0.type == "link"  }.compactMap { $0.link }
                if !photos.isEmpty {
                    ZStack(alignment: .topTrailing) {
                        PhotoGrid(photos: photos, onTap: { idx in
                            photoViewerIndex = idx
                            showPhotoViewer  = true
                        })
                        Button { showMediaForward = true } label: {
                            Image(systemName: "arrowshape.turn.up.right.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(.black.opacity(0.55))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                    .padding(.horizontal, 14).padding(.top, 8)
                }
                ForEach(videos.indices, id: \.self) { i in
                    ZStack(alignment: .topTrailing) {
                        VideoCard(video: videos[i])
                        Button { showMediaForward = true } label: {
                            Image(systemName: "arrowshape.turn.up.right.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(.black.opacity(0.55))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                    .padding(.horizontal, 14).padding(.top, 8)
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
                Button { showRepostSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath").font(.system(size: 15)).foregroundStyle(Color.onSurfaceMut)
                        if let rc = post.reposts?.count, rc > 0 {
                            Text("\(rc)").font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                        }
                    }
                }
                .buttonStyle(.plain)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        // Full-screen photo viewer
        .fullScreenCover(isPresented: $showPhotoViewer) {
            let photos = (post.attachments ?? []).filter { $0.type == "photo" }.compactMap { $0.photo }
            PhotoViewerSheet(photos: photos, initialIndex: photoViewerIndex)
        }
        // Repost sheet
        .sheet(isPresented: $showRepostSheet) {
            RepostSheet(post: post, authorName: authorName)
        }
        // Media forward sheet
        .sheet(isPresented: $showMediaForward) {
            MediaForwardSheet(post: post)
        }
    }

    @ViewBuilder
    private var authorDestination: some View {
        if post.authorId < 0 {
            CommunityDetailView(group: VKGroup(
                id: -post.authorId, name: authorName,
                photo100: authorPhoto, photo200: nil,
                membersCount: nil, description: nil,
                activity: nil, isMember: nil,
                isAdmin: nil, isClosed: nil, screenName: nil
            ))
        } else if post.authorId > 0 {
            FriendProfileView(user: VKUser(
                id: post.authorId,
                firstName: String(authorName.split(separator:" ").first ?? ""),
                lastName: String(authorName.split(separator:" ").dropFirst().first ?? ""),
                photo100: authorPhoto, photo200: nil,
                online: nil, status: nil, verified: nil,
                deactivated: nil, hasMobile: nil, verificationInfo: nil,
                city: nil, followersCount: nil, bdate: nil
            ))
        } else {
            EmptyView()
        }
    }

    private func fmtViews(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}

// MARK: - ExpandableText
struct ExpandableText: View {
    let text: String
    @State private var expanded = false
    private let limit = 300

    // Detect URLs in text
    static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    private func attributedText(_ str: String) -> AttributedString {
        var attr = AttributedString(str)
        attr.font = .system(size: 14)
        attr.foregroundColor = UIColor(Color.onSurface)
        // Highlight URLs
        let nsStr = str as NSString
        let range = NSRange(location: 0, length: nsStr.length)
        let matches = Self.detector?.matches(in: str, options: [], range: range) ?? []
        for match in matches {
            guard let url = match.url,
                  let lo = Range(match.range, in: str),
                  let attrRange = Range(lo, in: attr) else { continue }
            attr[attrRange].foregroundColor = UIColor(Color.cyberBlue)
            attr[attrRange].underlineStyle  = .single
            attr[attrRange].link = url
        }
        return attr
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let long  = text.count > limit
            let shown = !expanded && long ? String(text.prefix(limit)) + "…" : text
            Text(attributedText(shown))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .environment(\.openURL, OpenURLAction { url in
                    UIApplication.shared.open(url)
                    return .handled
                })
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
struct PhotoGrid: View {
    let photos: [VKPhoto]
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let count = min(photos.count, 4)
            photoLayout(count: count, width: w)
        }
        .frame(maxWidth: .infinity)
        .frame(height: photoHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var photoHeight: CGFloat {
        switch min(photos.count, 4) {
        case 1: return 260
        case 2: return 180
        case 3: return 220
        default: return 260
        }
    }

    @ViewBuilder
    private func photoLayout(count: Int, width: CGFloat) -> some View {
        switch count {
        case 1:
            tappablePhotoCell(photos[0], index: 0)
                .frame(width: width, height: 260)
        case 2:
            HStack(spacing: 2) {
                tappablePhotoCell(photos[0], index: 0).frame(width: (width - 2) / 2, height: 180)
                tappablePhotoCell(photos[1], index: 1).frame(width: (width - 2) / 2, height: 180)
            }
        case 3:
            HStack(spacing: 2) {
                tappablePhotoCell(photos[0], index: 0).frame(width: (width - 2) * 0.6, height: 220)
                VStack(spacing: 2) {
                    tappablePhotoCell(photos[1], index: 1).frame(width: (width - 2) * 0.4, height: 109)
                    tappablePhotoCell(photos[2], index: 2).frame(width: (width - 2) * 0.4, height: 109)
                }
            }
        default:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    tappablePhotoCell(photos[0], index: 0).frame(width: (width - 2) / 2, height: 129)
                    tappablePhotoCell(photos[1], index: 1).frame(width: (width - 2) / 2, height: 129)
                }
                HStack(spacing: 2) {
                    tappablePhotoCell(photos[2], index: 2).frame(width: (width - 2) / 2, height: 129)
                    tappablePhotoCell(photos[3], index: 3).frame(width: (width - 2) / 2, height: 129)
                }
            }
        }
    }

    @ViewBuilder
    private func photoCell(_ p: VKPhoto) -> some View {
        let url = p.maxUrl.flatMap(URL.init)
        Color.surfaceVar
            .overlay(
                Group {
                    if let url {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "photo").foregroundStyle(Color.onSurfaceMut)
                            default:
                                ProgressView().tint(.cyberBlue)
                            }
                        }
                    }
                }
            )
            .clipped()
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func tappablePhotoCell(_ p: VKPhoto, index: Int) -> some View {
        photoCell(p)
            .onTapGesture { onTap?(index) }
            .contentShape(Rectangle())
    }
}

// MARK: - LinkPreview
struct LinkPreview: View {
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

// MARK: - Photo Viewer (full-screen)
struct PhotoViewerSheet: View {
    let photos: [VKPhoto]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var current: Int = 0
    @State private var saved = false
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Swipeable photo pages
            TabView(selection: $current) {
                ForEach(photos.indices, id: \.self) { idx in
                    ZoomablePhoto(url: photos[idx].maxUrl.flatMap(URL.init))
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Top bar
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("\(current + 1) / \(photos.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    // Save button
                    Button {
                        savePhoto()
                    } label: {
                        Image(systemName: saved ? "checkmark" : "arrow.down.to.line")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                Spacer()
            }
        }
        .onAppear { current = initialIndex }
    }

    private func savePhoto() {
        guard let urlStr = photos[current].maxUrl,
              let url = URL(string: urlStr) else { return }
        Task {
            if let data = try? await URLSession.shared.data(from: url).0,
               let img  = UIImage(data: data) {
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                await MainActor.run {
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { saved = false }
                    }
                }
            }
        }
    }
}

// Zoomable photo with pinch gesture
private struct ZoomablePhoto: View {
    let url: URL?
    @State private var scale:      CGFloat = 1
    @State private var lastScale:  CGFloat = 1
    @State private var offset:     CGSize  = .zero
    @State private var lastOffset: CGSize  = .zero

    var body: some View {
        GeometryReader { geo in
            Group {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .scaleEffect(scale)
                                .offset(offset)
                                // Pinch to zoom
                                .gesture(
                                    MagnifyGesture()
                                        .onChanged { v in
                                            scale = max(1, min(5, lastScale * v.magnification))
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            if scale <= 1 {
                                                withAnimation(.spring(response: 0.3)) {
                                                    scale = 1; offset = .zero
                                                    lastScale = 1; lastOffset = .zero
                                                }
                                            }
                                        }
                                )
                                // Drag only when zoomed — don't block TabView horizontal swipe
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 10)
                                        .onChanged { v in
                                            guard scale > 1 else { return }
                                            offset = CGSize(
                                                width:  lastOffset.width  + v.translation.width,
                                                height: lastOffset.height + v.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            guard scale > 1 else { return }
                                            lastOffset = offset
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation(.spring(response: 0.3)) {
                                        if scale > 1 {
                                            scale = 1; offset = .zero
                                            lastScale = 1; lastOffset = .zero
                                        } else {
                                            scale = 2.5; lastScale = 2.5
                                        }
                                    }
                                }
                        default:
                            ProgressView().tint(.white)
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        // Reset zoom on swipe-away (when scale == 1, let TabView handle gesture)
    }
}

// MARK: - Repost Sheet
struct RepostSheet: View {
    let post: VKWallPost
    let authorName: String
    @Environment(\.dismiss) private var dismiss
    @State private var dialogs:  [DialogItem] = []
    @State private var loading   = true
    @State private var message   = ""
    @State private var sending   = false
    @State private var sent      = false
    @State private var searchQ   = ""
    @FocusState private var msgFocused: Bool

    private var filtered: [DialogItem] {
        searchQ.isEmpty ? dialogs :
        dialogs.filter { $0.name.lowercased().contains(searchQ.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message input
                HStack(spacing: 10) {
                    Image(systemName: "pencil").foregroundStyle(Color.cyberBlue)
                    TextField("Сообщение (необязательно)", text: $message)
                        .font(.system(size: 14))
                        .focused($msgFocused)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.surfaceVar)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.onSurfaceMut).font(.system(size: 14))
                    TextField("Поиск диалога...", text: $searchQ)
                        .font(.system(size: 14)).autocorrectionDisabled()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.surfaceVar)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 14).padding(.bottom, 8)

                Divider().background(Color.divider)

                if loading {
                    Spacer(); ProgressView().tint(.cyberBlue); Spacer()
                } else {
                    List(filtered) { dialog in
                        Button { sendRepost(to: dialog) } label: {
                            HStack(spacing: 12) {
                                AvatarView(url: dialog.avatar, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dialog.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.onSurface).lineLimit(1)
                                    Text(dialog.lastMessage)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.onSurfaceMut).lineLimit(1)
                                }
                                Spacer()
                                if sending { ProgressView().tint(.cyberBlue) }
                                if sent    { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.surface)
                        .listRowSeparatorTint(Color.divider)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .background(Color.background)
            .navigationTitle("Переслать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .task { await loadDialogs() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadDialogs() async {
        loading = true
        dialogs = (try? await VKAPIClient.shared.getDialogs()) ?? []
        loading = false
    }

    private func sendRepost(to dialog: DialogItem) {
        guard !sending else { return }
        sending = true
        let attachment = "wall\(post.postOwnerId)_\(post.id)"
        let text = message.isEmpty ? "" : message
        Task {
            _ = try? await VKAPIClient.shared.sendMessage(
                peerId: dialog.peerId,
                text: text,
                attachment: attachment
            )
            await MainActor.run {
                sending = false
                sent = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
            }
        }
    }
}

// MARK: - Media Forward Sheet
struct MediaForwardSheet: View {
    let post: VKWallPost
    @Environment(\.dismiss) private var dismiss
    @State private var dialogs:   [DialogItem] = []
    @State private var loading    = true
    @State private var sending    = false
    @State private var sentTo:    Set<Int> = []
    @State private var searchQ    = ""

    // Media items for selection
    private var photos: [VKPhoto] {
        (post.attachments ?? []).filter { $0.type == "photo" }.compactMap { $0.photo }
    }
    private var videos: [VKVideoAttachment] {
        (post.attachments ?? []).filter { $0.type == "video" }.compactMap { $0.video }
    }

    @State private var selectedPhotos: Set<Int> = []
    @State private var selectedVideos: Set<Int> = []

    private var hasSelection: Bool { !selectedPhotos.isEmpty || !selectedVideos.isEmpty }

    private var filtered: [DialogItem] {
        searchQ.isEmpty ? dialogs :
        dialogs.filter { $0.name.lowercased().contains(searchQ.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Media selection grid
                if !photos.isEmpty || !videos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Photos
                            ForEach(photos.indices, id: \.self) { i in
                                mediaThumb(
                                    urlStr: photos[i].maxUrl,
                                    icon: "photo",
                                    selected: selectedPhotos.contains(i)
                                ) {
                                    if selectedPhotos.contains(i) { selectedPhotos.remove(i) }
                                    else { selectedPhotos.insert(i) }
                                }
                            }
                            // Videos
                            ForEach(videos.indices, id: \.self) { i in
                                mediaThumb(
                                    urlStr: videos[i].thumbUrl,
                                    icon: "video",
                                    selected: selectedVideos.contains(i)
                                ) {
                                    if selectedVideos.contains(i) { selectedVideos.remove(i) }
                                    else { selectedVideos.insert(i) }
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    .background(Color.surfaceVar)

                    if hasSelection {
                        Text("Выбрано: \(selectedPhotos.count + selectedVideos.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cyberBlue)
                            .padding(.vertical, 4)
                    } else {
                        Text("Выберите медиафайлы для пересылки")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.onSurfaceMut)
                            .padding(.vertical, 4)
                    }

                    Divider().background(Color.divider)
                }

                // Dialog search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.onSurfaceMut).font(.system(size: 14))
                    TextField("Поиск диалога...", text: $searchQ)
                        .font(.system(size: 14)).autocorrectionDisabled()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.surfaceVar)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 14).padding(.vertical, 8)

                Divider().background(Color.divider)

                if loading {
                    Spacer(); ProgressView().tint(.cyberBlue); Spacer()
                } else {
                    List(filtered) { dialog in
                        Button { send(to: dialog) } label: {
                            HStack(spacing: 12) {
                                AvatarView(url: dialog.avatar, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dialog.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.onSurface).lineLimit(1)
                                    Text(dialog.lastMessage)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.onSurfaceMut).lineLimit(1)
                                }
                                Spacer()
                                if sentTo.contains(dialog.peerId) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if sending {
                                    ProgressView().tint(.cyberBlue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasSelection)
                        .listRowBackground(hasSelection ? Color.surface : Color.surface.opacity(0.5))
                        .listRowSeparatorTint(Color.divider)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .background(Color.background)
            .navigationTitle("Переслать медиа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if hasSelection {
                        Button("Выбрать всё") {
                            photos.indices.forEach { selectedPhotos.insert($0) }
                            videos.indices.forEach { selectedVideos.insert($0) }
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cyberBlue)
                    }
                }
            }
            .task { await loadDialogs() }
            .onAppear {
                // Auto-select all by default
                photos.indices.forEach { selectedPhotos.insert($0) }
                videos.indices.forEach { selectedVideos.insert($0) }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func mediaThumb(urlStr: String?, icon: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            if let urlStr, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else { Color.surfaceVar }
                }
                .frame(width: 72, height: 72)
                .clipped()
            } else {
                Color.surfaceVar
                    .frame(width: 72, height: 72)
                    .overlay(Image(systemName: icon).foregroundStyle(Color.onSurfaceMut))
            }

            // Selection indicator
            ZStack {
                Circle()
                    .fill(selected ? Color.cyberBlue : Color.black.opacity(0.5))
                    .frame(width: 22, height: 22)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
            selected ? Color.cyberBlue : Color.clear, lineWidth: 2))
        .onTapGesture { onTap() }
    }

    private func loadDialogs() async {
        loading = true
        dialogs = (try? await VKAPIClient.shared.getDialogs()) ?? []
        loading = false
    }

    private func send(to dialog: DialogItem) {
        guard hasSelection, !sending else { return }
        sending = true

        // Build attachment string: photo{ownerid}_{id},video{ownerid}_{id},...
        var attachments: [String] = []

        for i in selectedPhotos {
            let p = photos[i]
            attachments.append("photo\(p.id)_\(p.id)") // will fix with real ownerId below
        }
        // photos need owner_id — stored in maxUrl path isn't reliable; use post owner
        let postOwnerId = post.postOwnerId

        attachments = []
        for i in selectedPhotos.sorted() {
            if i < photos.count {
                // VK photo attachment format: photo{owner_id}_{photo_id}
                attachments.append("photo\(postOwnerId)_\(photos[i].id)")
            }
        }
        for i in selectedVideos.sorted() {
            if i < videos.count {
                attachments.append("video\(videos[i].ownerId)_\(videos[i].id)")
            }
        }

        let attachStr = attachments.joined(separator: ",")

        Task {
            _ = try? await VKAPIClient.shared.sendMessage(
                peerId: dialog.peerId,
                text: "",
                attachment: attachStr
            )
            await MainActor.run {
                sending = false
                sentTo.insert(dialog.peerId)
            }
        }
    }
}

// MARK: - Poll View
struct PollView: View {
    let poll:    VKPoll
    let ownerId: Int
    @ObservedObject private var s = SettingsStore.shared
    @State private var fullPoll:  VKPoll? = nil
    @State private var loading = false

    private var displayed: VKPoll { fullPoll ?? poll }
    private var hasResults: Bool { displayed.answers.contains { $0.votes > 0 } }
    private var totalVotes: Int { displayed.votes }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cyberBlue)
                Text("Опрос")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cyberBlue)
                if displayed.anonymous == 1 {
                    Text("· анонимный")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
                Text("\(totalVotes) гол.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.onSurfaceMut)
            }

            Text(displayed.question)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.onSurface)

            if s.showPollResults && hasResults {
                // Show results
                VStack(spacing: 6) {
                    ForEach(displayed.answers) { answer in
                        PollAnswerRow(answer: answer, total: totalVotes)
                    }
                }
            } else if s.showPollResults && !loading {
                // Fetch results
                Button {
                    Task { await loadResults() }
                } label: {
                    Text(loading ? "Загрузка..." : "Показать результаты")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.cyberBlue)
                }
                .buttonStyle(.plain)
                .task { await loadResults() }
            } else {
                // Just show answer options without results
                VStack(spacing: 5) {
                    ForEach(displayed.answers) { answer in
                        HStack(spacing: 8) {
                            Circle()
                                .stroke(Color.divider, lineWidth: 1.5)
                                .frame(width: 16, height: 16)
                            Text(answer.text)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.onSurface)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(red:0.07,green:0.08,blue:0.13))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.divider, lineWidth: 0.5))
    }

    private func loadResults() async {
        guard fullPoll == nil && !loading else { return }
        loading = true
        fullPoll = try? await VKAPIClient.shared.getPoll(pollId: poll.id, ownerId: ownerId)
        loading = false
    }
}

private struct PollAnswerRow: View {
    let answer: VKPollAnswer
    let total:  Int

    var pct: Double { total > 0 ? answer.rate : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(answer.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.onSurface)
                Spacer()
                Text("\(Int(pct.rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cyberBlue)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.divider)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.cyberBlue)
                        .frame(width: geo.size.width * CGFloat(pct / 100), height: 4)
                }
            }
            .frame(height: 4)
            Text("\(answer.votes) гол.")
                .font(.system(size: 10))
                .foregroundStyle(Color.onSurfaceMut)
        }
    }
}
