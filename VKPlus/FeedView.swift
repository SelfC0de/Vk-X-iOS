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
private struct PostCard: View {
    let post:        VKWallPost
    let authorName:  String
    let authorPhoto: String?
    let onLike:      () -> Void

    @State private var showPhotoViewer = false
    @State private var photoViewerIndex = 0
    @State private var showRepostSheet  = false

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
                let links  = att.filter { $0.type == "link"  }.compactMap { $0.link }
                if !photos.isEmpty {
                    PhotoGrid(photos: photos, onTap: { idx in
                        photoViewerIndex = idx
                        showPhotoViewer  = true
                    }).padding(.horizontal, 14).padding(.top, 8)
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

    // Detect URLs in text
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

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
private struct PhotoGrid: View {
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
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

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
                                .gesture(
                                    SimultaneousGesture(
                                        MagnifyGesture()
                                            .onChanged { v in
                                                scale = max(1, min(5, lastScale * v.magnification))
                                            }
                                            .onEnded { _ in
                                                lastScale = scale
                                                if scale < 1 { withAnimation { scale = 1; offset = .zero; lastScale = 1; lastOffset = .zero } }
                                            },
                                        DragGesture()
                                            .onChanged { v in
                                                guard scale > 1 else { return }
                                                offset = CGSize(width: lastOffset.width + v.translation.width,
                                                                height: lastOffset.height + v.translation.height)
                                            }
                                            .onEnded { _ in lastOffset = offset }
                                    )
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation(.spring()) {
                                        if scale > 1 { scale = 1; offset = .zero; lastScale = 1; lastOffset = .zero }
                                        else { scale = 2.5; lastScale = 2.5 }
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
