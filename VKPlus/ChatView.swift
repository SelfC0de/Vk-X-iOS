import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - ChatView

// MARK: - Ghost Read Store
// Persists which incoming messages should appear unread when ghostMode is on
// Key: "ghost_unread_<peerId>", Value: Set<Int> of message IDs that arrived while ghostMode was on
private struct GhostReadStore {
    static func markUnread(peerId: Int, msgId: Int) {
        let key = "ghost_unread_\(peerId)"
        var set = load(peerId: peerId)
        set.insert(msgId)
        UserDefaults.standard.set(Array(set), forKey: key)
    }
    static func clearAll(peerId: Int) {
        UserDefaults.standard.removeObject(forKey: "ghost_unread_\(peerId)")
    }
    static func load(peerId: Int) -> Set<Int> {
        let key = "ghost_unread_\(peerId)"
        let arr = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        return Set(arr)
    }
    static func isGhostUnread(peerId: Int, msgId: Int) -> Bool {
        load(peerId: peerId).contains(msgId)
    }
}

struct ChatView: View {
    let peerId:    Int
    let peerName:  String
    var peerAvatar: String? = nil
    @ObservedObject private var store = SettingsStore.shared
    @State private var messages:   [VKMessage] = []
    @State private var draft       = ""
    @State private var isLoading   = false
    @State private var isSending   = false
    @State private var myId        = 0
    @State private var myAvatar:   String? = nil
    @State private var avatarMap:  [Int: String] = [:]
    @State private var showAttach  = false
    @State private var photoItem:   PhotosPickerItem? = nil
    // Profile navigation from link
    @State private var profileUser:  VKUser? = nil
    @State private var showProfile  = false
    @State private var messagePollingTask: Task<Void, Never>? = nil
    // Forward
    @State private var forwardMsg:  VKMessage? = nil
    @State private var showForward  = false
    // Reactions
    @State private var reactMsg:    VKMessage? = nil
    @State private var showReact    = false
    // Search
    @State private var showSearch   = false
    @State private var searchQuery  = ""
    // Emoji
    @State private var showEmoji    = false
    // Voice record (VK-style hold-to-record)
    @State private var isRecording    = false
    @State private var isCancelling   = false   // swipe-left cancel zone
    @State private var recordSeconds  = 0
    @State private var recordTimer:   Timer? = nil
    @State private var audioRecorder: AVAudioRecorder? = nil
    @State private var recordedURL:   URL? = nil
    @State private var voiceReadyURL:  URL? = nil  // local URL for preview before send
    @State private var dragOffsetX:   CGFloat = 0
    @State private var videoItem2:  PhotosPickerItem? = nil
    @State private var audioItem:   PhotosPickerItem? = nil
    @State private var showFilePicker  = false
    @State private var showPhotoPicker = false
    @State private var showVideoPicker = false
    @State private var pendingAttach: String? = nil
    @State private var isUploading   = false
    @State private var editingMsg: VKMessage? = nil
    @State private var replyMsg:   VKMessage? = nil
    @State private var peerOnline   = false
    @State private var peerPlatform: Int? = nil
    @State private var peerTyping    = false
    @State private var currentPts:   Int = 0         // LongPoll pts for delete tracking
    @State private var deletedMsgIds: Set<Int> = []  // IDs deleted during current session (LP)
    @State private var persistedDeletedIds: Set<Int> = []  // IDs deleted in previous sessions
    @State private var fakeTyping    = false
    @State private var fakeTypingTask: Task<Void, Never>? = nil
    @State private var typeStatusTask: Task<Void, Never>? = nil
    @State private var typingTimer: Timer? = nil
    @State private var lastTypingSent: Date = .distantPast

    // Screen width for bubble sizing
    private var W: CGFloat { UIScreen.main.bounds.width }
    // Avatar slot width
    private let AV: CGFloat = 28
    // Max bubble width: VK-style ~75% of usable width
    private var maxW: CGFloat { (W - 32) * 0.75 }
    private var filteredMessages: [VKMessage] {
        guard !searchQuery.isEmpty else { return messages }
        return messages.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        // Use GeometryReader ONLY for safe area bottom, not for sizing
        ZStack(alignment: .bottom) {
            // Background layer — absolutely positioned, not affecting layout
            Group {
                if let data = store.chatBgImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: W, height: UIScreen.main.bounds.height)
                        .clipped()
                        .overlay(Color.black.opacity(0.5))
                        .ignoresSafeArea()
                } else {
                    Color(red:0.04,green:0.05,blue:0.09)
                        .ignoresSafeArea()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // Content — normal flow, not affected by bg
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView().tint(.cyberBlue)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach((searchQuery.isEmpty ? messages : filteredMessages).reversed()) { msg in
                                    let wasDeleted = deletedMsgIds.contains(msg.id) || persistedDeletedIds.contains(msg.id)
                                    if wasDeleted {
                                        DeletedBubble(isOutgoing: msg.isOutgoing)
                                    } else {
                                    BubbleView(
                                        msg:      msg,
                                        myId:     myId,
                                        peerId:   peerId,
                                        allMsgs:  messages,
                                        avatarMap: avatarMap,
                                        myAvatar:  myAvatar,
                                        maxW:      maxW,
                                        onReply:   { replyMsg = msg },
                                        onEdit:    { if msg.fromId == myId { editingMsg = msg; draft = msg.text } },
                                        onDelete:  { Task { await deleteMsg(msg) } },
                                        onForward:       { forwardMsg = msg; showForward = true },
                                        onReact:         { reactMsg = msg; showReact = true },
                                        onSavePhoto:     { url in Task { await saveImageToGallery(urlStr: url) } },
                                        onDownloadVoice: { url in Task { await downloadVoice(urlStr: url) } },
                                        onDownloadVideo: { vid in Task { await downloadVideo(vid) } },
                                        onVKLink: { name in
                                            Task {
                                                if let u = try? await VKAPIClient.shared.getUserById(name) {
                                                    await MainActor.run {
                                                        profileUser = u
                                                        showProfile = true
                                                    }
                                                }
                                            }
                                        }
                                    )
                                    .id(msg.id)
                                    } // end else (not deleted)
                                }
                                // Anchor at bottom — always scroll here
                                Color.clear.frame(height: 1).id("bottom_anchor")
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                        }
                        // Scroll to bottom after load
                        .onChange(of: messages.count) { _, _ in
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                        .onAppear {
                            // Immediate scroll without animation on first appear
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                }
                inputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    if store.hideSender {
                        ZStack {
                            Circle().fill(Color.surfaceVar).frame(width: 32, height: 32)
                            Image(systemName: "person.fill.xmark")
                                .foregroundStyle(Color.onSurfaceMut).font(.system(size: 14))
                        }
                    } else {
                        AvatarView(url: peerAvatar, size: 32)
                            .overlay(Circle().stroke(Color.cyberBlue.opacity(0.3), lineWidth: 0.8))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.hideSender ? "Пользователь скрыт" : peerName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(store.hideSender ? Color.onSurfaceMut : Color.onSurface)
                        if !store.hideSender {
                            if store.currentTypeStatus != .none && typeStatusTask != nil {
                                    TypingStatusView(label: store.currentTypeStatus.statusLabel)
                                } else if peerTyping { TypingStatusView() }
                            else {
                                HStack(spacing: 4) {
                                    if store.showPlatformIcon,
                                       let plat = peerPlatform, plat > 0 {
                                        let ls = VKLastSeen(time: nil, platform: plat)
                                        Image(systemName: ls.platformIcon)
                                            .font(.system(size: 10))
                                            .foregroundStyle(peerOnline ? Color.cyberAccent : Color.onSurfaceMut)
                                        Text(peerOnline
                                            ? "в сети · \(ls.platformName)"
                                            : ls.platformName)
                                            .font(.system(size: 11))
                                            .foregroundStyle(peerOnline ? Color.cyberAccent : Color.onSurfaceMut)
                                    } else {
                                        Text(peerOnline ? "в сети" : "не в сети")
                                            .font(.system(size: 11))
                                            .foregroundStyle(peerOnline ? Color.cyberAccent : Color.onSurfaceMut)
                                    }
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { openPeerProfile() }
                }
            }
        }
        .toolbarBackground(Color(red:0.05,green:0.06,blue:0.10), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSearch.toggle() } label: {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.onSurfaceMut)
                }
            }
        }
        .sheet(isPresented: $showForward) {
            if let msg = forwardMsg {
                ForwardSheet(message: msg, myId: myId)
            }
        }
        .sheet(isPresented: $showReact) {
            if let msg = reactMsg {
                ReactionsSheet(message: msg, peerId: peerId)
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let u = profileUser { FriendProfileView(user: u) }
        }
        .task {
            await load()
            startMessagePolling()
            startTypeStatusLoop()
        }
        .onChange(of: store.typeStatus) { _, _ in startTypeStatusLoop() }
        .onChange(of: store.antiTyping) { _, _ in startTypeStatusLoop() }
        .onDisappear {
            messagePollingTask?.cancel(); messagePollingTask = nil
            fakeTypingTask?.cancel(); fakeTypingTask = nil; fakeTyping = false
            typeStatusTask?.cancel(); typeStatusTask = nil
            SettingsStore.shared.activeTypingPeerId = 0
        }
        .confirmationDialog("Прикрепить", isPresented: $showAttach, titleVisibility: .visible) {
            Button("Фото") { showPhotoPicker = true }
            Button("Видео") { showVideoPicker = true }
            Button("Документ / Файл") { showFilePicker = true }
            Button("Отмена", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .photosPicker(isPresented: $showVideoPicker, selection: $videoItem2, matching: .videos)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio, .pdf, .text, .data, .zip, .item],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleFileImport(result) }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await uploadAndAttach(item: item, isVideo: false) }
        }
        .onChange(of: videoItem2) { _, item in
            guard let item else { return }
            Task { await uploadAndAttach(item: item, isVideo: true) }
        }
        .overlay(alignment: .top) { EmptyView()
        }
    }

    // MARK: - Input bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Search bar (slides in)
            if showSearch {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.onSurfaceMut)
                    TextField("Поиск в переписке...", text: $searchQuery)
                        .foregroundStyle(Color.onSurface).font(.system(size: 14))
                    if !searchQuery.isEmpty {
                        Button { searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.onSurfaceMut)
                        }
                    }
                    Button { showSearch = false; searchQuery = "" } label: {
                        Text("Отмена").font(.system(size: 13)).foregroundStyle(Color.cyberBlue)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(red:0.07,green:0.08,blue:0.13))
                Divider().background(Color.divider)
            }
            if isRecording { recordingBanner }
            if let r = replyMsg   { replyBanner(r)  }
            if let e = editingMsg { editBanner(e)   }
            if let vurl = voiceReadyURL { voicePreviewBanner(vurl) }
            uploadingStrip
            if let a = pendingAttach { attachBanner(a) }
            if showEmoji { emojiPanel }

            HStack(spacing: 8) {
                Button { showAttach = true } label: {
                    Image(systemName: "paperclip").font(.system(size: 20))
                        .foregroundStyle(Color(red:0.4,green:0.5,blue:0.65))
                        .frame(width: 36, height: 36)
                }
                Button { showEmoji.toggle() } label: {
                    Image(systemName: "face.smiling").font(.system(size: 20))
                        .foregroundStyle(showEmoji ? Color.cyberBlue : Color(red:0.4,green:0.5,blue:0.65))
                        .frame(width: 32, height: 32)
                }
                TextField(editingMsg != nil ? "Редактировать..." : "Сообщение...",
                          text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(red:0.08,green:0.09,blue:0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .foregroundStyle(.white).font(.system(size: 15))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(
                        editingMsg != nil ? Color.cyberBlue.opacity(0.5) :
                        replyMsg   != nil ? Color(red:0.5,green:0.4,blue:0.9).opacity(0.5) : Color.clear,
                        lineWidth: 0.8))
                    .onChange(of: draft) { _, v in if !v.isEmpty { notifyTyping() } }

                if draft.trimmingCharacters(in: .whitespaces).isEmpty && pendingAttach == nil && voiceReadyURL == nil && !isSending {
                    VoiceRecordButton(
                        isRecording: $isRecording,
                        isCancelling: $isCancelling,
                        dragOffsetX: $dragOffsetX,
                        onStart: startRecording,
                        onStop: stopRecording,
                        onCancel: {
                            recordTimer?.invalidate(); recordTimer = nil
                            audioRecorder?.stop(); audioRecorder = nil
                            isRecording = false; isCancelling = false
                            dragOffsetX = 0; recordSeconds = 0
                            recordedURL = nil; voiceReadyURL = nil
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    )
                } else {
                    Button { Task { await send() } } label: {
                        if isSending { ProgressView().tint(.cyberBlue).frame(width: 34, height: 34) }
                        else {
                            Image(systemName: editingMsg != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(Color.cyberBlue)
                        }
                    }
                    .disabled(isSending)
                }

                if editingMsg != nil || replyMsg != nil {
                    Button { editingMsg = nil; replyMsg = nil; draft = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22))
                            .foregroundStyle(Color(red:0.4,green:0.5,blue:0.65))
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color(red:0.05,green:0.06,blue:0.10))
        }
    }

    @ViewBuilder private func replyBanner(_ msg: VKMessage) -> some View {
        let accentColor = Color(red:0.5,green:0.4,blue:0.9)
        HStack(spacing: 10) {
            // Accent line
            Rectangle()
                .fill(accentColor)
                .frame(width: 2)
                .clipShape(Capsule())

            // Photo thumbnail if available
            if let photo = msg.attachments?.first(where: { $0.type == "photo" })?.photo,
               let url = photo.maxUrl {
                AsyncImage(url: URL(string: url)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.onSurfaceMut.opacity(0.15))
                            .frame(width: 36, height: 36)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                // Sender name
                let senderName = msg.isOutgoing ? "Вы" : "Собеседник"
                Text(senderName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)

                // Content preview
                let attDesc: String? = {
                    guard let atts = msg.attachments, !atts.isEmpty else { return nil }
                    let first = atts[0]
                    switch first.type {
                    case "photo":         return "📷 Фото"
                    case "video":         return "🎬 Видео"
                    case "audio":         return "🎵 " + (first.audio?.title ?? "Аудио")
                    case "audio_message": return "🎤 Голосовое"
                    case "doc":           return "📎 " + (first.doc?.title ?? "Документ")
                    case "sticker":       return "🎨 Стикер"
                    case "link":          return "🔗 Ссылка"
                    default:              return "📎 Вложение"
                    }
                }()
                let preview = attDesc ?? (msg.text.isEmpty ? "Сообщение" : String(msg.text.prefix(60)))
                Text(preview)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red:0.6,green:0.7,blue:0.85))
                    .lineLimit(1)
            }
            Spacer()
            Button { replyMsg = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.onSurfaceMut)
                    .frame(width: 18, height: 18)
                    .background(Color.onSurfaceMut.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color(red:0.07,green:0.085,blue:0.13))
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.divider.opacity(0.5)), alignment: .top)
    }

    @ViewBuilder private func attachBanner(_ att: String) -> some View {
        let icon  = att.hasPrefix("photo") ? "photo.fill"   :
                    att.hasPrefix("video") ? "video.fill"   :
                    att.hasPrefix("audio") ? "waveform"     :
                    att.hasPrefix("doc")   ? "doc.fill"     : "paperclip"
        let label = att.hasPrefix("photo") ? "Фото"         :
                    att.hasPrefix("video") ? "Видео"        :
                    att.hasPrefix("audio") ? "Аудио"        :
                    att.hasPrefix("doc")   ? "Документ"     : "Файл"
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color(red:0.0,green:0.75,blue:0.55))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.onSurface)
            Text("прикреплено")
                .font(.system(size: 12))
                .foregroundStyle(Color.onSurfaceMut)
            Spacer()
            Button { pendingAttach = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.onSurfaceMut)
                    .frame(width: 18, height: 18)
                    .background(Color.onSurfaceMut.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Color(red:0.07,green:0.085,blue:0.13))
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.divider.opacity(0.5)), alignment: .top)
    }

    // Compact uploading strip shown while isUploading=true
    @ViewBuilder private var uploadingStrip: some View {
        if isUploading {
            HStack(spacing: 6) {
                ProgressView()
                    .tint(Color(red:0.0,green:0.75,blue:0.55))
                    .scaleEffect(0.75)
                    .frame(width: 16, height: 16)
                Text("Загружаем...")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.onSurfaceMut)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(Color(red:0.07,green:0.085,blue:0.13))
            .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.divider.opacity(0.5)), alignment: .top)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder private func voicePreviewBanner(_ url: URL) -> some View {
        HStack(spacing: 10) {
            // Waveform preview player
            AudioPlayerView(url: url.absoluteString, duration: recordSeconds, isVoice: true)
                .frame(maxWidth: .infinity)
            // Send button
            Button {
                Task { await uploadAndSendVoice() }
            } label: {
                if isUploading {
                    ProgressView().tint(.cyberBlue).scaleEffect(0.9)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.cyberBlue)
                }
            }
            .buttonStyle(.plain)
            // Delete button
            Button {
                voiceReadyURL = nil
                recordedURL   = nil
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.errorRed)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(red:0.06,green:0.07,blue:0.11))
        .overlay(
            Rectangle().fill(Color(red:0.11,green:0.63,blue:0.95)).frame(height: 1),
            alignment: .top
        )
    }

    @ViewBuilder private func editBanner(_ msg: VKMessage) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.cyberBlue).frame(width: 3).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 1) {
                Text("Редактирование").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.cyberBlue)
                Text(String(msg.text.prefix(60))).font(.system(size: 12))
                    .foregroundStyle(Color(red:0.6,green:0.7,blue:0.85)).lineLimit(1)
            }
            Spacer()
            Button { editingMsg = nil; draft = "" } label: { Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(Color(red:0.4,green:0.5,blue:0.65)) }
        }
        .padding(.horizontal, 14).padding(.vertical, 8).background(Color(red:0.07,green:0.08,blue:0.13))
    }

    // MARK: - Load
    private func openPeerProfile() {
        guard !store.hideSender && peerId > 0 else { return }
        Task {
            if let u = try? await VKAPIClient.shared.getUserById("\(peerId)") {
                await MainActor.run { profileUser = u; showProfile = true }
            }
        }
    }

    private func startMessagePolling() {
        messagePollingTask?.cancel()
        messagePollingTask = Task {
            await runLongPoll()
        }
    }

    // VK LongPoll — receives push events instantly, no 3s delay
    private func runLongPoll() async {
        var server: LongPollServer
        do {
            server = try await VKAPIClient.shared.getLongPollServer()
        } catch {
            // LongPoll init failed — fall back to 3s polling
            await fallbackPolling()
            return
        }

        // Load persisted deleted IDs
        await MainActor.run {
            persistedDeletedIds = SettingsStore.shared.deletedIds(for: peerId)
        }

        var ts  = server.ts
        var pts = server.pts
        await MainActor.run { currentPts = pts }

        while !Task.isCancelled {
            do {
                let events = try await VKAPIClient.shared.pollLongPoll(server: server, ts: ts, pts: pts)
                ts  = events.ts
                if let newPts = events.pts { pts = newPts; await MainActor.run { currentPts = newPts } }

                // Process LongPoll events
                var hasNewMessage = false
                for upd in events.updates {
                    guard let code = upd.first as? Int else { continue }
                    switch code {
                    case 4:
                        // New message: upd[3] = peer_id
                        let msgPeerId = upd.count > 3 ? (upd[3] as? Int ?? 0) : 0
                        if msgPeerId == peerId { hasNewMessage = true }
                    case 6:
                        // Messages read by peer: upd[1] = peer_id, upd[2] = local_id (last read)
                        // We don't need to do anything UI-wise — already handled by message flags
                        break
                    case 7:
                        // Messages read by me — could update read receipts locally
                        break
                    case 18:
                        // Message deleted (pts event): upd[1] = message_id (negative = deleted for all)
                        let delMsgId = upd.count > 1 ? abs(upd[1] as? Int ?? 0) : 0
                        if delMsgId > 0 {
                            deletedMsgIds.insert(delMsgId)
                            SettingsStore.shared.markDeleted(delMsgId, peerId: peerId)
                            persistedDeletedIds.insert(delMsgId)
                            // Refresh messages to reflect deletion
                            let fresh2 = (try? await VKAPIClient.shared.getMessages(peerId: peerId, count: 50)) ?? []
                            if !fresh2.isEmpty {
                                await MainActor.run {
                                    withAnimation(.easeIn(duration: 0.15)) { messages = fresh2 }
                                }
                            }
                        }
                    case 61:
                        // Peer typing: upd[1] = user_id, upd[2] = flags (1=typing)
                        let userId   = upd.count > 1 ? (upd[1] as? Int ?? 0) : 0
                        let isTyping = upd.count > 2 ? (upd[2] as? Int ?? 0) == 1 : true
                        // Show indicator only if it's the peer (not me)
                        if userId != 0 && userId != myId {
                            await MainActor.run {
                                peerTyping = isTyping
                                typingTimer?.invalidate()
                                if isTyping {
                                    typingTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { _ in
                                        peerTyping = false
                                    }
                                }
                            }
                        }
                    default: break
                    }
                }

                if hasNewMessage {
                    let fresh = (try? await VKAPIClient.shared.getMessages(peerId: peerId, count: 50)) ?? []
                    if !fresh.isEmpty {
                        let currentMaxId = messages.map { $0.id }.max() ?? 0
                        let freshMaxId   = fresh.map { $0.id }.max() ?? 0
                        if freshMaxId > currentMaxId || fresh.count != messages.count {
                            let freshIds = Set(fresh.map { $0.id })
                            let oldIds   = Set(messages.map { $0.id })
                            // IDs present before but gone now = deleted by peer
                            let newlyDeleted = oldIds.subtracting(freshIds).filter { $0 > 0 }
                            await MainActor.run {
                                for id in newlyDeleted {
                                    SettingsStore.shared.markDeleted(id, peerId: peerId)
                                    persistedDeletedIds.insert(id)
                                }
                                withAnimation(.easeIn(duration: 0.15)) {
                                    messages = fresh
                                }
                            }
                        }
                    }
                }

            } catch {
                // LongPoll failed (failed=2/3) — reinit server
                guard !Task.isCancelled else { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if let newServer = try? await VKAPIClient.shared.getLongPollServer() {
                    server = newServer
                    ts = newServer.ts
                }
            }
        }
    }

    // Fallback: simple polling every 3s if LongPoll unavailable
    private func fallbackPolling() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { break }
            let fresh = (try? await VKAPIClient.shared.getMessages(peerId: peerId, count: 50)) ?? []
            guard !fresh.isEmpty else { continue }
            let currentMaxId = messages.map { $0.id }.max() ?? 0
            let freshMaxId   = fresh.map { $0.id }.max() ?? 0
            if freshMaxId > currentMaxId || fresh.count != messages.count {
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.15)) { messages = fresh }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        if let me = try? await VKAPIClient.shared.getProfile() { myId = me.id; myAvatar = me.photo100; TokenStorage.shared.cachedUserId = me.id }
        let fetched = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? []
        let ghost = SettingsStore.shared.ghostMode
        // Mark all incoming messages as ghost-unread when ghostMode is on
        if ghost {
            for msg in fetched where (msg.out ?? 0) == 0 {
                GhostReadStore.markUnread(peerId: peerId, msgId: msg.id)
            }
        }
        messages = fetched
        if peerId > 0, let user = try? await VKAPIClient.shared.getUserById("\(peerId)") {
            peerOnline = user.isOnline
            peerPlatform = user.lastSeen?.platform
        }
        let ids = Array(Set(messages.map { $0.fromId }.filter { $0 != myId && $0 > 0 }))
        if !ids.isEmpty, let users = try? await VKAPIClient.shared.getUsers(ids: ids.map(String.init).joined(separator: ",")) {
            for u in users { avatarMap[u.id] = u.photo100 }
        }
        isLoading = false
    }

    private func notifyTyping() {
        let s = SettingsStore.shared
        guard !s.antiTyping else { return }
        // If typeStatus loop is already running, skip manual notify
        guard s.currentTypeStatus == .none else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTypingSent) > 5 else { return }
        lastTypingSent = now
        Task { await VKAPIClient.shared.sendTypingDirect(peerId: peerId, type: "typing") }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty || pendingAttach != nil else { return }
        isSending = true
        if let editing = editingMsg {
            do {
                try await VKAPIClient.shared.editMessage(peerId: peerId, messageId: editing.id, text: text)
                if let idx = messages.firstIndex(where: { $0.id == editing.id }) {
                    messages[idx] = VKMessage(id: editing.id, fromId: editing.fromId, text: text,
                                              date: editing.date, replyMessage: editing.replyMessage, attachments: editing.attachments, out: editing.out, readState: editing.readState)
                }
                ToastManager.shared.show("Изменено", icon: "pencil.circle.fill", style: .success)
            } catch { ToastManager.shared.show("Ошибка", icon: "exclamationmark.triangle.fill", style: .warning) }
            editingMsg = nil
        } else {
            let replyId = replyMsg?.id
            let attach = pendingAttach
            draft = ""; replyMsg = nil; pendingAttach = nil
            do {
                _ = try await VKAPIClient.shared.sendMessage(peerId: peerId, text: text, replyTo: replyId, attachment: attach)
                messages = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? messages
                ToastManager.shared.show("Отправлено", icon: "paperplane.fill", style: .success)
            } catch { draft = text; ToastManager.shared.show("Ошибка", icon: "exclamationmark.triangle.fill", style: .warning) }
        }
        isSending = false; draft = ""
    }

    // MARK: - Upload & attach helpers
    private func uploadAndAttach(item: PhotosPickerItem, isVideo: Bool) async {
        isUploading = true
        defer { isUploading = false }
        do {
            if isVideo {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let att = try await VKAPIClient.shared.uploadDocForMessage(
                    peerId: peerId, data: data, filename: "video.mp4", mimeType: "video/mp4")
                pendingAttach = att
                ToastManager.shared.show("Видео прикреплено", icon: "video.fill", style: .success)
            } else {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let att = try await VKAPIClient.shared.uploadPhotoForMessage(peerId: peerId, imageData: data)
                pendingAttach = att
                ToastManager.shared.show("Фото прикреплено", icon: "photo.fill", style: .success)
            }
        } catch {
            ToastManager.shared.show("Ошибка загрузки", icon: "exclamationmark.triangle.fill", style: .warning)
        }
        photoItem = nil; videoItem2 = nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        isUploading = true
        defer { isUploading = false }
        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            let mime: String
            switch ext {
            case "mp3","m4a","aac","ogg","flac": mime = "audio/mpeg"
            case "mp4","mov","avi":              mime = "video/mp4"
            case "pdf":                          mime = "application/pdf"
            default:                             mime = "application/octet-stream"
            }
            let att = try await VKAPIClient.shared.uploadDocForMessage(
                peerId: peerId, data: data, filename: filename, mimeType: mime)
            pendingAttach = att
            ToastManager.shared.show("\(filename) прикреплён", icon: "paperclip", style: .success)
        } catch {
            ToastManager.shared.show("Ошибка загрузки", icon: "exclamationmark.triangle.fill", style: .warning)
        }
    }

    // MARK: - Save photo
    private func saveImageToGallery(urlStr: String) async {
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else {
            ToastManager.shared.show("Ошибка сохранения", icon: "exclamationmark.triangle.fill", style: .warning); return
        }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        ToastManager.shared.show("Фото сохранено", icon: "photo.badge.checkmark", style: .success)
    }

    // MARK: - Download voice
    private func downloadVoice(urlStr: String) async {
        let ext  = urlStr.hasSuffix(".ogg") ? "ogg" : "mp3"
        let name = "voice_\(Int(Date().timeIntervalSince1970)).\(ext)"
        await DownloadManager.shared.downloadAudio(from: urlStr, filename: name, isVoice: true)
    }

    // MARK: - Download video
    private func downloadVideo(_ vid: VKVideoAttachment) async {
        var urlStr = vid._directUrl
        if urlStr == nil {
            if let full = try? await VKAPIClient.shared.getVideo(ownerId: vid.ownerId, videoId: vid.id) {
                urlStr = full._directUrl
            }
        }
        guard let str = urlStr, let url = URL(string: str) else {
            ToastManager.shared.show("Прямая ссылка недоступна", icon: "exclamationmark.triangle.fill", style: .warning)
            return
        }
        ToastManager.shared.show("Загрузка видео...", icon: "arrow.down.circle", style: .info)
        do {
            let (tmpUrl, _) = try await URLSession.shared.download(from: url)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("video_\(Int(Date().timeIntervalSince1970)).mp4")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmpUrl, to: dest)
            await MainActor.run {
                let av = UIActivityViewController(activityItems: [dest], applicationActivities: nil)
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first?.rootViewController?
                    .present(av, animated: true)
            }
        } catch {
            ToastManager.shared.show("Ошибка загрузки видео", icon: "exclamationmark.triangle.fill", style: .warning)
        }
    }


    // MARK: - Type Status Loop
    private func startTypeStatusLoop() {
        typeStatusTask?.cancel()
        typeStatusTask = nil
        let s = SettingsStore.shared
        guard s.currentTypeStatus != .none else { return }
        guard !s.antiTyping else { return }
        let statusType = s.currentTypeStatus.rawValue
        SettingsStore.shared.activeTypingPeerId = peerId
        typeStatusTask = Task {
            // Send immediately on open
            await VKAPIClient.shared.sendTypingDirect(peerId: peerId, type: statusType)
            // VK typing status expires after ~5s — resend every 4s
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { break }
                let cur = SettingsStore.shared.currentTypeStatus
                guard cur != .none && !SettingsStore.shared.antiTyping else { break }
                await VKAPIClient.shared.sendTypingDirect(peerId: peerId, type: cur.rawValue)
            }
        }
    }

    // MARK: - Fake Typing
    private func toggleFakeTyping() {
        if fakeTyping {
            fakeTyping = false
            fakeTypingTask?.cancel(); fakeTypingTask = nil
            // Resume typeStatus loop if it was set
            startTypeStatusLoop()
            ToastManager.shared.show("Имитация набора остановлена", icon: "keyboard", style: .info)
        } else {
            // Pause typeStatus loop — fakeTyping takes over
            typeStatusTask?.cancel(); typeStatusTask = nil
            fakeTyping = true
            ToastManager.shared.show("Имитация набора активна", icon: "keyboard.fill", style: .success)
            fakeTypingTask = Task {
                while !Task.isCancelled && fakeTyping {
                    await VKAPIClient.shared.sendTypingDirect(peerId: peerId, type: "typing")
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                }
            }
        }
    }

    // MARK: - Voice recording


    private func startRecording() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: beginRecording()
            case .denied:
                ToastManager.shared.show("Нет доступа к микрофону", icon: "mic.slash.fill", style: .warning)
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted { self.beginRecording() }
                        else { ToastManager.shared.show("Нет доступа к микрофону", icon: "mic.slash.fill", style: .warning) }
                    }
                }
            @unknown default: beginRecording()
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted: beginRecording()
            case .denied:
                ToastManager.shared.show("Нет доступа к микрофону", icon: "mic.slash.fill", style: .warning)
            case .undetermined:
                session.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted { self.beginRecording() }
                        else { ToastManager.shared.show("Нет доступа к микрофону", icon: "mic.slash.fill", style: .warning) }
                    }
                }
            @unknown default: beginRecording()
            }
        }
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Deactivate first to reset any conflicting state
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("vkplus_voice_\(Int(Date().timeIntervalSince1970)).m4a")

            // Use safe settings — AAC 44100 is universally supported
            let settings: [String: Any] = [
                AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey:          44100.0,
                AVNumberOfChannelsKey:    1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey:      64000
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                ToastManager.shared.show("Не удалось начать запись", icon: "mic.slash.fill", style: .warning)
                return
            }
            audioRecorder = recorder
            recordedURL   = url
            isRecording   = true
            recordSeconds = 0
            // Start seconds counter on main thread
            DispatchQueue.main.async {
                self.recordTimer?.invalidate()
                self.recordTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    self.recordSeconds += 1
                }
                RunLoop.main.add(self.recordTimer!, forMode: .common)
            }
        } catch {
            ToastManager.shared.show("Ошибка микрофона: \(error.localizedDescription)", icon: "mic.slash.fill", style: .warning)
        }
    }

    private func stopRecording() {
        recordTimer?.invalidate(); recordTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        guard let url = recordedURL else { return }
        voiceReadyURL = url
    }

    private func uploadAndSendVoice() async {
        guard let url = voiceReadyURL else { return }
        isUploading = true
        do {
            let data = try Data(contentsOf: url)
            let att = try await VKAPIClient.shared.uploadDocForMessage(
                peerId: peerId, data: data, filename: "voice.m4a", mimeType: "audio/m4a")
            pendingAttach = att
            voiceReadyURL = nil
            await send()
        } catch {
            ToastManager.shared.show("Ошибка загрузки голосового", icon: "exclamationmark.triangle.fill", style: .warning)
        }
        isUploading = false
    }

    // MARK: - Emoji panel
    private var emojiPanel: some View {
        let emojis = ["😀","😂","😍","🥰","😎","🤔","😢","😡","👍","👎",
                      "❤️","🔥","✅","🎉","🙏","💪","😴","🤣","😱","🥺",
                      "👏","💯","🤝","😏","🤭","😅","🙈","💀","👀","🫡"]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(emojis, id: \.self) { e in
                    Button(e) { draft += e }
                        .font(.system(size: 26))
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 50)
        .background(Color(red:0.07,green:0.08,blue:0.13))
    }

    // MARK: - Recording overlay (VK-style)
    private var recordingBanner: some View {
        HStack(spacing: 12) {
            // Red dot pulse
            Circle().fill(Color.red).frame(width: 8, height: 8)
                .opacity(isRecording ? 1 : 0)
                .scaleEffect(isRecording ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
            // Timer
            Text(String(format: "%d:%02d", recordSeconds / 60, recordSeconds % 60))
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Color.onSurface)
            Spacer()
            // Swipe hint
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12))
                    .opacity(0.6)
                Text("Смахните для отмены")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.onSurfaceMut)
            }
            .opacity(isCancelling ? 0 : 1)
            .animation(.easeOut(duration: 0.15), value: isCancelling)

            if isCancelling {
                Text("Отмена")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.red)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(red:0.05,green:0.05,blue:0.09))
        .offset(x: min(0, dragOffsetX * 0.4))
    }

    private func deleteMsg(_ msg: VKMessage) async {
        do {
            try await VKAPIClient.shared.deleteMessage(messageIds: [msg.id])
            withAnimation { messages.removeAll { $0.id == msg.id } }
            ToastManager.shared.show("Удалено", icon: "trash.fill", style: .info)
        } catch { ToastManager.shared.show("Ошибка", icon: "exclamationmark.triangle.fill", style: .warning) }
    }
}

// MARK: - Typing indicator
private struct TypingStatusView: View {
    var label: String = "Печатает"
    @State private var phases: [CGFloat] = [0, 0, 0]
    @State private var step = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundStyle(Color.cyberBlue)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.cyberBlue).frame(width: 4, height: 4)
                        .offset(y: phases[i])
                        .animation(.easeInOut(duration: 0.3), value: phases[i])
                }
            }
        }
        .onReceive(timer) { _ in
            let prev = step; step = (step+1)%3
            withAnimation { phases[prev] = 0; phases[step] = -4 }
        }
    }
}

// MARK: - BubbleView
private struct BubbleView: View {
    let msg:       VKMessage
    let myId:      Int
    let peerId:    Int
    let allMsgs:   [VKMessage]
    let avatarMap: [Int: String]
    let myAvatar:  String?
    let maxW:      CGFloat
    let onReply:   () -> Void
    let onEdit:    () -> Void
    let onDelete:  () -> Void
    let onForward:       () -> Void
    let onReact:         () -> Void
    let onSavePhoto:     ((String) -> Void)?
    let onDownloadVoice: ((String) -> Void)?
    let onDownloadVideo: ((VKVideoAttachment) -> Void)?
    let onVKLink:        ((String) -> Void)?

    @ObservedObject private var store = SettingsStore.shared
    @State private var showPhotoViewer = false
    @State private var profileUserId: Int? = nil

    @State private var photoViewerIndex = 0
    @State private var showVideoPlayer = false
    @State private var videoItem: VKVideoAttachment? = nil

    private var isMe: Bool { msg.fromId == myId }
    private var bg:   Color { Color(hex: isMe ? store.myBubbleHex : store.theirBubbleHex) }
    private var fg:   Color { Color(red:0.92,green:0.96,blue:1.00) }
    private var tc:   Color { isMe ? Color(red:0.55,green:0.75,blue:0.95) : Color(red:0.40,green:0.45,blue:0.58) }
    private let AV:   CGFloat = 28

    // Read status indicator
    @ViewBuilder
    private var readIndicator: some View {
        if isMe {
            // Outgoing: single grey tick = unread, double blue ticks = read
            let isRead = (msg.readState ?? 0) == 1
            HStack(spacing: -3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isRead ? Color.cyberBlue : Color.onSurfaceMut.opacity(0.5))
                if isRead {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.cyberBlue)
                }
            }
        } else if SettingsStore.shared.ghostMode && GhostReadStore.isGhostUnread(peerId: peerId, msgId: msg.id) {
            // Incoming while ghostMode: show orange dot = server doesn't know you read it
            Circle()
                .fill(Color.orange.opacity(0.85))
                .frame(width: 6, height: 6)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            // Left: other's avatar or spacer
            if isMe {
                Spacer(minLength: AV + 4)
            } else {
                let hideIt = SettingsStore.shared.hideSender
                Group {
                    if hideIt {
                        ZStack {
                            Circle().fill(Color.surfaceVar)
                            Image(systemName: "person.fill.xmark")
                                .foregroundStyle(Color.onSurfaceMut).font(.system(size: 11))
                        }
                    } else {
                        AvatarView(url: avatarMap[msg.fromId], size: AV)
                            .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    }
                }
                .frame(width: AV, height: AV)
                .alignmentGuide(.bottom) { d in d[.bottom] }
            }

            // Bubble content — naturally sized, capped at maxW
            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                // Reply quote — use embedded object from API
                if let reply = msg.replyMessage {
                    quotedView(reply)
                }
                // Attachments
                if let atts = msg.attachments, !atts.isEmpty {
                    attachmentsView(atts)
                }
                // Text
                if !msg.text.isEmpty {
                    BubbleTextBubble(
                        text:    msg.text,
                        time:    timeStr(msg.date),
                        fg:      fg,
                        tc:      tc,
                        bg:      bg,
                        isMe:    isMe,
                        maxW:    maxW,
                        onVKLink: onVKLink,
                        readIndicator: AnyView(readIndicator)
                    )
                }
                if msg.text.isEmpty {
                    HStack(spacing: 2) {
                        Text(timeStr(msg.date)).font(.system(size: 10)).foregroundStyle(tc)
                        readIndicator
                    }.padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: maxW, alignment: isMe ? .trailing : .leading)
            .contextMenu {
                Button { onReply() } label: { Label("Ответить", systemImage: "arrowshape.turn.up.left") }
                Button { onForward() } label: { Label("Переслать", systemImage: "arrowshape.turn.up.right") }
                Button { onReact() } label: { Label("Реакция", systemImage: "face.smiling") }
                if isMe { Button { onEdit() } label: { Label("Редактировать", systemImage: "pencil") } }
                Button(role: .destructive) { onDelete() } label: { Label("Удалить", systemImage: "trash") }
                if !msg.text.isEmpty {
                    Button {
                        UIPasteboard.general.string = msg.text
                        ToastManager.shared.show("Скопировано", icon: "doc.on.clipboard", style: .info)
                    } label: { Label("Копировать", systemImage: "doc.on.doc") }
                }
                // Save media
                if let att = msg.attachments?.first {
                    if att.type == "photo", let url = att.photo?.maxUrl {
                        Button {
                            onSavePhoto?(url)
                        } label: { Label("Сохранить фото", systemImage: "photo.badge.arrow.down") }
                    }
                    if att.type == "audio_message", let url = att.audioMessage?.linkMp3 ?? att.audioMessage?.linkOgg {
                        Button {
                            onDownloadVoice?(url)
                        } label: { Label("Скачать голосовое", systemImage: "arrow.down.circle") }
                    }
                    if att.type == "video", let vid = att.video {
                        Button {
                            onDownloadVideo?(vid)
                        } label: { Label("Скачать видео", systemImage: "arrow.down.video") }
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button { onReply() } label: {
                    Label("Ответить", systemImage: "arrowshape.turn.up.left")
                }.tint(Color(red:0.31,green:0.40,blue:0.55))
            }

            // Right: my avatar or spacer
            if isMe {
                AvatarView(url: myAvatar, size: AV)
                    .overlay(Circle().stroke(Color.cyberBlue.opacity(0.2), lineWidth: 0.5))
                    .frame(width: AV)
                    .alignmentGuide(.bottom) { d in d[.bottom] }
            } else {
                Spacer(minLength: AV + 4)
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder private func quotedView(_ q: VKReplyMessage) -> some View {
        let accentColor = isMe ? Color.cyberBlue : Color(red:0.5,green:0.4,blue:0.9)
        HStack(spacing: 6) {
            Rectangle().fill(accentColor).frame(width: 2).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 1) {
                Text(q.fromId == myId ? "Вы" : "Собеседник")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                if q.text.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip").font(.system(size: 11)).foregroundStyle(accentColor.opacity(0.7))
                        Text("Вложение").font(.system(size: 12)).foregroundStyle(accentColor.opacity(0.7))
                    }
                } else {
                    Text(String(q.text.prefix(80)))
                        .font(.system(size: 12))
                        .foregroundStyle(isMe ? Color(red:0.7,green:0.85,blue:1.0) : Color(red:0.75,green:0.70,blue:0.95))
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(isMe ? Color(red:0.06,green:0.20,blue:0.38) : Color(red:0.09,green:0.09,blue:0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func attachmentsView(_ atts: [VKAttachment]) -> some View {
        // Collect all photos for gallery view
        let photoUrls = atts.filter { $0.type == "photo" }.compactMap { $0.photo?.maxUrl }
        ForEach(atts.indices, id: \.self) { i in
            let a = atts[i]
            Group {
            switch a.type {
            case "photo":
                if let url = a.photo?.maxUrl {
                    let photoIdx = atts[0..<i].filter { $0.type == "photo" }.count
                    Button {
                        photoViewerIndex = photoIdx
                        showPhotoViewer = true
                    } label: {
                        AttachmentPhoto(url: url)
                            .frame(maxWidth: min(maxW, 220), maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }

            case "audio_message":
                if let vm = a.audioMessage, let url = vm.linkMp3 ?? vm.linkOgg {
                    AudioPlayerView(url: url, duration: vm.duration, isVoice: true)
                        .frame(maxWidth: min(maxW, 240))
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .id(url)
                }

            case "audio":
                if let au = a.audio, let url = au.url {
                    HStack(spacing: 6) {
                        AudioPlayerView(
                                url: url,
                                duration: au.duration ?? 0,
                                isVoice: false,
                                artist: au.artist,
                                title: au.title
                            )
                            .frame(maxWidth: min(maxW - 36, 204))
                            .background(bg)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        CircularDownloadButton(urlStr: url, size: 30, iconColor: Color.cyberBlue) {
                            Task {
                                let artist = au.artist ?? ""
                                let title  = au.title  ?? "audio"
                                let name   = artist.isEmpty ? title : "\(artist) - \(title)"
                                await DownloadManager.shared.downloadAudio(from: url, filename: name)
                            }
                        }
                    }
                    if let artist = au.artist, let title = au.title {
                        Text("\(artist) — \(title)")
                            .font(.system(size: 12)).foregroundStyle(fg.opacity(0.8))
                            .lineLimit(1).frame(maxWidth: min(maxW, 240), alignment: .leading)
                    }
                }

            case "video":
                if let vid = a.video {
                    Button {
                        videoItem = vid
                        showVideoPlayer = true
                    } label: {
                        ZStack {
                            if let thumb = vid.thumbUrl {
                                AttachmentPhoto(url: thumb)
                                    .frame(maxWidth: min(maxW, 220), maxHeight: 140)
                                    .clipped()
                            } else {
                                Color(red:0.08,green:0.10,blue:0.16)
                                    .frame(maxWidth: min(maxW, 220), maxHeight: 140)
                            }
                            // Play button overlay
                            Circle().fill(Color.black.opacity(0.5)).frame(width: 48, height: 48)
                            Image(systemName: "play.fill").foregroundStyle(.white).font(.system(size: 20))
                            // Duration badge
                            if let dur = vid.duration {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Text(durationStr(dur))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6).padding(.vertical, 3)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                            .padding(6)
                                    }
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    if let title = vid.title, !title.isEmpty {
                        Text(title).font(.system(size: 12)).foregroundStyle(fg.opacity(0.8))
                            .lineLimit(1).frame(maxWidth: min(maxW, 220), alignment: .leading)
                    }
                }

            case "doc":
                if let doc = a.doc {
                    let docUrl = doc.url.flatMap(URL.init)
                    Button {
                        if let u = docUrl { UIApplication.shared.open(u) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: docIcon(doc.ext)).foregroundStyle(Color.cyberBlue).font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.title).font(.system(size: 13)).foregroundStyle(fg).lineLimit(1)
                                if let ext = doc.ext {
                                    Text(ext.uppercased()).font(.system(size: 10)).foregroundStyle(Color.cyberBlue.opacity(0.8))
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle").foregroundStyle(Color.cyberBlue.opacity(0.7)).font(.system(size: 14))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .frame(maxWidth: min(maxW, 240))
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

            case "poll":
                if let p = a.poll {
                    PollView(poll: p, ownerId: peerId)
                        .frame(maxWidth: min(maxW, 280))
                }

            default:
                EmptyView()
            }
            }
        }
        .sheet(isPresented: $showPhotoViewer) {
            MediaViewerSheet(photos: photoUrls, startIndex: photoViewerIndex)
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let vid = videoItem {
                VideoPlayerSheet(videoId: vid.id, ownerId: vid.ownerId, thumb: vid.thumbUrl)
            }
        }

    }

    private func durationStr(_ s: Int) -> String { String(format: "%d:%02d", s/60, s%60) }
    private func docIcon(_ ext: String?) -> String {
        switch ext?.lowercased() {
        case "pdf": return "doc.richtext.fill"
        case "mp3","ogg","aac","flac","wav": return "music.note"
        case "mp4","mov","avi","mkv": return "film.fill"
        case "jpg","jpeg","png","gif","webp": return "photo.fill"
        case "zip","rar","7z": return "archivebox.fill"
        default: return "doc.fill"
        }
    }

    private func timeStr(_ ts: Int) -> String {
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return df.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}

// MARK: - Attachment photo helper (fill mode with cache)
private struct AttachmentPhoto: View {
    let url: String
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(red:0.08,green:0.10,blue:0.16)
                    .overlay(ProgressView().tint(.white).scaleEffect(0.6))
            }
        }
        .task(id: url) {
            if let c = ImageCache.shared.get(url) { image = c; return }
            guard let u = URL(string: url),
                  let (data,_) = try? await URLSession.shared.data(from: u),
                  let img = UIImage(data: data) else { return }
            ImageCache.shared.set(url, image: img); image = img
        }
    }
}

// MARK: - Link-aware message text
// MARK: - BubbleTextBubble
// VK-style: text flows naturally, time+ticks sit at bottom-right.
// Uses a UITextView width probe to decide if time fits on the last line.
private struct BubbleTextBubble: View {
    let text:       String
    let time:       String
    let fg:         Color
    let tc:         Color
    let bg:         Color
    let isMe:       Bool
    let maxW:       CGFloat
    var onVKLink:   ((String) -> Void)? = nil
    let readIndicator: AnyView

    // Width of "HH:MM  ✓✓" footer — ~50 pt is enough for time + two ticks
    private let footerW: CGFloat = 52
    private let hPad:    CGFloat = 12
    private let vPad:    CGFloat = 8

    // Natural text width at maxW minus horizontal padding
    private var textAreaW: CGFloat { maxW - hPad * 2 }

    // Measure natural single-line width of the text
    private func measuredTextWidth() -> CGFloat {
        let font = UIFont.systemFont(ofSize: 15)
        let size = (text as NSString).boundingRect(
            with: CGSize(width: 10_000, height: 400),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(size.width)
    }

    // Natural last-line width (multiline case)
    private func lastLineWidth() -> CGFloat {
        let font  = UIFont.systemFont(ofSize: 15)
        let textW = textAreaW
        let size  = (text as NSString).boundingRect(
            with: CGSize(width: textW, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        // Approximate last line: total width mod lineWidth
        let totalH   = ceil(size.height)
        let lineH    = font.lineHeight
        let lines    = max(1, Int(round(totalH / lineH)))
        if lines == 1 { return min(ceil(size.width), textW) }
        // For multiline: measure last line by splitting on newlines
        // Simple heuristic: remainder width
        let words    = text.components(separatedBy: .whitespacesAndNewlines)
        var lineW: CGFloat = 0
        var lastW: CGFloat = 0
        for word in words {
            let ww = ceil((word + " " as NSString).size(withAttributes: [.font: font]).width)
            if lineW + ww > textW {
                lastW = 0
                lineW = ww
            } else {
                lineW += ww
                lastW = lineW
            }
        }
        return min(lastW, textW)
    }

    // Does footer (time+ticks) fit on the last line of text?
    private var footerFitsOnLastLine: Bool {
        let naturalW = measuredTextWidth()
        let lastW    = lastLineWidth()
        if naturalW <= textAreaW {
            // Single-line message: fits if text + gap + footer <= textAreaW
            return naturalW + 6 + footerW <= textAreaW
        } else {
            // Multi-line: footer fits if last line has room
            return lastW + 6 + footerW <= textAreaW
        }
    }

    // Ideal bubble content width
    private var bubbleContentW: CGFloat {
        let naturalW = measuredTextWidth()
        if naturalW <= textAreaW {
            // Short text: width = text + maybe footer
            let needed = naturalW + hPad * 2
            if footerFitsOnLastLine {
                return min(needed + 6 + footerW, maxW)
            } else {
                return min(max(needed, footerW + hPad * 2 + 8), maxW)
            }
        }
        return maxW
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius:     isMe ? 16 : 4,
            bottomLeadingRadius:  isMe ? 16 : 4,
            bottomTrailingRadius: isMe ?  4 : 16,
            topTrailingRadius:    16)
    }

    var body: some View {
        if footerFitsOnLastLine {
            // Footer appended inline after text via trailing padding trick
            ZStack(alignment: .bottomTrailing) {
                MessageTextView(
                    text: text + "\u{00A0}\u{00A0}\u{00A0}\u{00A0}\u{00A0}",  // non-breaking spaces reserve footer room
                    textColor: fg,
                    onVKLink: onVKLink
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: bubbleContentW - hPad * 2)

                footerView
                    .padding(.bottom, 1)
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(width: bubbleContentW)
            .background(bg)
            .clipShape(shape)
            .overlay(shape.stroke(Color.white.opacity(0.07), lineWidth: 0.5))
        } else {
            // Footer on its own line below text
            VStack(alignment: .trailing, spacing: 2) {
                MessageTextView(
                    text: text,
                    textColor: fg,
                    onVKLink: onVKLink
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                footerView
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(width: bubbleContentW)
            .background(bg)
            .clipShape(shape)
            .overlay(shape.stroke(Color.white.opacity(0.07), lineWidth: 0.5))
        }
    }

    private var footerView: some View {
        HStack(spacing: 2) {
            Text(time)
                .font(.system(size: 10))
                .foregroundStyle(tc)
                .fixedSize()
            readIndicator
        }
    }
}

private struct MessageTextView: View {
    let text: String
    let textColor: Color
    var onVKLink: ((String) -> Void)? = nil
    var onURL: ((URL) -> Void)? = nil

    var body: some View {
        LinkableText(
            text: text,
            textColor: textColor,
            onVKLink: { name in onVKLink?(name) },
            onURL: { url in UIApplication.shared.open(url) }
        )
    }
}

// UIViewRepresentable for proper tappable links
private struct LinkableText: UIViewRepresentable {
    let text: String
    let textColor: Color
    let onVKLink: (String) -> Void
    let onURL: (URL) -> Void

    private static let vkPattern = try? NSRegularExpression(
        pattern: #"https?://(?:www\.)?vk\.(?:com|ru)/([A-Za-z0-9_\.]+)"#,
        options: .caseInsensitive)
    private static let urlPattern = try? NSRegularExpression(
        pattern: #"https?://[^\s]+"#,
        options: .caseInsensitive)

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.onVKLink = onVKLink
        context.coordinator.onURL = onURL
        tv.attributedText = buildAttributedString()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onVKLink: onVKLink, onURL: onURL)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return size
    }

    private func buildAttributedString() -> NSAttributedString {
        let uiColor = UIColor(textColor)
        let base: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15),
            .foregroundColor: uiColor
        ]
        let result = NSMutableAttributedString(string: text, attributes: base)
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let linkColor = UIColor(Color.cyberBlue)

        // Parse VK markup [id123|Name] or [club123|Name] — make them tappable links
        let markupPattern = try? NSRegularExpression(
            pattern: #"\[([A-Za-z0-9_]+)\|([^\]]+)\]"#, options: [])
        if let matches = markupPattern?.matches(in: text, range: full) {
            for m in matches.reversed() {
                guard m.numberOfRanges >= 3 else { continue }
                let screenName = ns.substring(with: m.range(at: 1))
                let displayName = ns.substring(with: m.range(at: 2))
                let linkUrl = URL(string: "https://vk.com/\(screenName)")!
                let linked = NSMutableAttributedString(string: displayName, attributes: [
                    .font: UIFont.systemFont(ofSize: 15),
                    .foregroundColor: linkColor,
                    .link: linkUrl
                ])
                result.replaceCharacters(in: m.range, with: linked)
            }
        }
        // Rebuild ns after replacements
        let ns2 = result.string as NSString
        let full2 = NSRange(location: 0, length: ns2.length)

        // Apply VK links
        if let matches = Self.vkPattern?.matches(in: result.string, range: full2) {
            for m in matches {
                let urlStr = ns2.substring(with: m.range)
                if let url = URL(string: urlStr) {
                    result.addAttributes([
                        .link: url,
                        .foregroundColor: linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: m.range)
                }
            }
        }
        // Apply other URLs (skip VK already handled)
        if let matches = Self.urlPattern?.matches(in: result.string, range: full2) {
            for m in matches {
                let urlStr = ns2.substring(with: m.range)
                // Skip if already has link attribute
                var alreadyLinked = false
                result.enumerateAttribute(.link, in: m.range) { val, _, _ in
                    if val != nil { alreadyLinked = true }
                }
                if !alreadyLinked, let url = URL(string: urlStr) {
                    result.addAttributes([
                        .link: url,
                        .foregroundColor: linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: m.range)
                }
            }
        }
        return result
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var onVKLink: (String) -> Void
        var onURL: (URL) -> Void

        init(onVKLink: @escaping (String) -> Void, onURL: @escaping (URL) -> Void) {
            self.onVKLink = onVKLink
            self.onURL = onURL
        }

        func textView(_ textView: UITextView, shouldInteractWith url: URL,
                      in characterRange: NSRange) -> Bool {
            let str = url.absoluteString
            let pattern = try? NSRegularExpression(
                pattern: #"vk\.(?:com|ru)/([A-Za-z0-9_\.]+)"#, options: .caseInsensitive)
            let ns = str as NSString
            if let m = pattern?.firstMatch(in: str, range: NSRange(location: 0, length: ns.length)),
               m.numberOfRanges >= 2 {
                let name = ns.substring(with: m.range(at: 1))
                DispatchQueue.main.async { self.onVKLink(name) }
                return false
            }
            DispatchQueue.main.async { self.onURL(url) }
            return false
        }
    }
}



// MARK: - Voice Record Button (VK-style hold-to-record)
private struct VoiceRecordButton: View {
    @Binding var isRecording: Bool
    @Binding var isCancelling: Bool
    @Binding var dragOffsetX: CGFloat
    let onStart: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void

    @State private var isPressed = false
    private let cancelThreshold: CGFloat = -80

    var body: some View {
        ZStack {
            // Пульсирующий круг при записи
            if isRecording {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .scaleEffect(isRecording ? 1.3 : 1)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isRecording)
            }
            // Кнопка
            Circle()
                .fill(isRecording ? Color.red : Color(red:0.1,green:0.12,blue:0.18))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isRecording ? .white : Color(red:0.4,green:0.5,blue:0.65))
                )
                .scaleEffect(isPressed ? 1.1 : 1.0)
                .animation(.spring(response: 0.2), value: isPressed)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    if !isRecording {
                        isPressed = true
                        onStart()
                    }
                    dragOffsetX = val.translation.width
                    isCancelling = dragOffsetX < cancelThreshold
                }
                .onEnded { _ in
                    isPressed = false
                    if isCancelling {
                        onCancel()
                    } else if isRecording {
                        onStop()
                    }
                    dragOffsetX = 0
                    isCancelling = false
                }
        )
    }
}

// MARK: - Forward Sheet
struct ForwardSheet: View {
    let message: VKMessage
    let myId: Int
    @Environment(\.dismiss) var dismiss

    @State private var allDialogs:  [DialogItem] = []
    @State private var isLoading    = true
    @State private var sendingTo:   Int? = nil   // peerId currently sending to
    @State private var searchText   = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [DialogItem] {
        guard !searchText.isEmpty else { return allDialogs }
        let q = searchText.lowercased()
        return allDialogs.filter { $0.name.lowercased().contains(q) }
    }

    // Attachment preview for the message being forwarded
    private var msgPreview: String {
        if !message.text.isEmpty { return String(message.text.prefix(60)) }
        guard let atts = message.attachments, !atts.isEmpty else { return "Сообщение" }
        switch atts[0].type {
        case "photo":         return "📷 Фото"
        case "video":         return "🎬 Видео"
        case "audio":         return "🎵 " + (atts[0].audio?.title ?? "Аудио")
        case "audio_message": return "🎤 Голосовое"
        case "doc":           return "📎 " + (atts[0].doc?.title ?? "Документ")
        default:              return "📎 Вложение"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message preview strip
                HStack(spacing: 10) {
                    Rectangle().fill(Color.cyberBlue).frame(width: 3).clipShape(Capsule())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Переслать сообщение")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.cyberBlue)
                        Text(msgPreview)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.onSurfaceMut)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(red:0.06,green:0.07,blue:0.11))

                Divider().background(Color.divider)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.onSurfaceMut)
                        .font(.system(size: 14))
                    TextField("Поиск...", text: $searchText)
                        .foregroundStyle(Color.onSurface)
                        .font(.system(size: 15))
                        .focused($searchFocused)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.onSurfaceMut)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color(red:0.08,green:0.09,blue:0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(red:0.05,green:0.06,blue:0.10))

                Divider().background(Color.divider)

                // Dialog list
                if isLoading {
                    Spacer()
                    ProgressView().tint(.cyberBlue)
                    Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    Text(searchText.isEmpty ? "Нет диалогов" : "Ничего не найдено")
                        .foregroundStyle(Color.onSurfaceMut)
                        .font(.system(size: 14))
                    Spacer()
                } else {
                    List(filtered) { d in
                        Button {
                            guard sendingTo == nil else { return }
                            Task { await forward(to: d.peerId) }
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(url: d.avatar, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(d.name)
                                        .foregroundStyle(Color.onSurface)
                                        .font(.system(size: 15, weight: .medium))
                                        .lineLimit(1)
                                    if !d.lastMessage.isEmpty {
                                        Text(d.lastMessage)
                                            .foregroundStyle(Color.onSurfaceMut)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if sendingTo == d.peerId {
                                    ProgressView().tint(.cyberBlue).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.onSurfaceMut.opacity(0.4))
                                }
                            }
                        }
                        .listRowBackground(Color.surface)
                        .listRowSeparatorTint(Color.divider)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.background.ignoresSafeArea())
            .navigationTitle("Переслать в...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(Color.cyberBlue)
                }
            }
            .toolbarBackground(Color.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await loadDialogs() }
    }

    private func loadDialogs() async {
        isLoading = true
        let json = try? await VKAPIClient.shared.rawCall("messages.getConversations",
                        params: ["count": "80", "extended": "1"])
        guard let resp  = json?["response"] as? [String: Any],
              let items = resp["items"] as? [[String: Any]] else {
            isLoading = false; return
        }
        let profiles = (resp["profiles"] as? [[String: Any]]) ?? []
        let groups   = (resp["groups"]   as? [[String: Any]]) ?? []
        let pMap = Dictionary(uniqueKeysWithValues: profiles.compactMap { p -> (Int,[String:Any])? in
            guard let id = p["id"] as? Int else { return nil }; return (id, p) })
        let gMap = Dictionary(uniqueKeysWithValues: groups.compactMap { g -> (Int,[String:Any])? in
            guard let id = g["id"] as? Int else { return nil }; return (-id, g) })
        allDialogs = items.compactMap { item -> DialogItem? in
            guard let conv = item["conversation"] as? [String: Any],
                  let peer = conv["peer"] as? [String: Any],
                  let pid  = peer["id"] as? Int else { return nil }
            let lm = (item["last_message"] as? [String: Any])?["text"] as? String ?? ""
            if let p = pMap[pid] {
                let fn = ((p["first_name"] as? String ?? "") + " " + (p["last_name"] as? String ?? "")).trimmingCharacters(in: .whitespaces)
                return DialogItem(id: pid, name: fn, avatar: p["photo_100"] as? String,
                                  lastMessage: lm, isOnline: false, unreadCount: 0, peerId: pid)
            } else if let g = gMap[pid] {
                return DialogItem(id: pid, name: g["name"] as? String ?? "Беседа",
                                  avatar: g["photo_100"] as? String,
                                  lastMessage: lm, isOnline: false, unreadCount: 0, peerId: pid)
            } else if peer["type"] as? String == "chat" {
                // Group chat without extended info
                let title = (conv["chat_settings"] as? [String: Any])?["title"] as? String ?? "Беседа"
                let av    = ((conv["chat_settings"] as? [String: Any])?["photo"] as? [String: Any])?["photo_100"] as? String
                return DialogItem(id: pid, name: title, avatar: av,
                                  lastMessage: lm, isOnline: false, unreadCount: 0, peerId: pid)
            }
            return nil
        }
        isLoading = false
    }

    private func forward(to toPeerId: Int) async {
        sendingTo = toPeerId
        // VK API: forward object with conversation_message_ids (preferred) or message_id
        let cmid = message.id  // conversation_message_id == message.id for user dialogs
        // Build forward JSON — works for both personal and group chats
        let fwdObj: [String: Any] = [
            "conversation_message_ids": [cmid],
            "peer_id": toPeerId,
            "is_reply": false
        ]
        guard let fwdData = try? JSONSerialization.data(withJSONObject: fwdObj),
              let fwdStr  = String(data: fwdData, encoding: .utf8) else {
            sendingTo = nil; return
        }
        let result = try? await VKAPIClient.shared.rawCall("messages.send", params: [
            "peer_id":   "\(toPeerId)",
            "random_id": "\(Int.random(in: 1...Int.max))",
            "forward":   fwdStr
        ])
        let ok = result?["response"] != nil
        sendingTo = nil
        if ok {
            ToastManager.shared.show("Переслано", icon: "arrowshape.turn.up.right.fill", style: .success)
            dismiss()
        } else {
            ToastManager.shared.show("Ошибка пересылки", icon: "exclamationmark.triangle.fill", style: .warning)
        }
    }
}

// MARK: - Reactions Sheet
struct ReactionsSheet: View {
    let message: VKMessage
    let peerId: Int
    @Environment(\.dismiss) var dismiss

    private let reactions = [
        ("❤️","heart"),("👍","like"),("👎","dislike"),("😂","lol"),
        ("😢","cry"),("😱","scared"),("😡","angry"),("🔥","fire"),
        ("🎉","party"),("💩","poop"),("🤔","thinking"),("🥰","love_face")
    ]

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.divider).frame(width: 40, height: 4).padding(.top, 10)
            Text("Добавить реакцию").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.onSurface)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(reactions, id: \.0) { (emoji, id) in
                    Button {
                        Task { await sendReaction(id) }
                    } label: {
                        Text(emoji).font(.system(size: 32))
                            .frame(width: 50, height: 50)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .presentationDetents([.height(220)])
        .presentationBackground(Color.background)
    }

    private func sendReaction(_ reactionId: String) async {
        _ = try? await VKAPIClient.shared.rawCall("messages.sendReaction", params: [
            "peer_id":    "\(peerId)",
            "cmid":       "\(message.id)",
            "reaction_id": reactionId == "heart" ? "1" :
                           reactionId == "like"  ? "2" :
                           reactionId == "dislike" ? "3" :
                           reactionId == "lol"   ? "4" :
                           reactionId == "cry"   ? "5" :
                           reactionId == "scared" ? "6" :
                           reactionId == "angry" ? "7" :
                           reactionId == "fire"  ? "8" :
                           reactionId == "party" ? "9" :
                           reactionId == "poop"  ? "10" :
                           reactionId == "thinking" ? "11" : "12"
        ])
        ToastManager.shared.show("Реакция добавлена", icon: "face.smiling.fill", style: .success)
        dismiss()
    }
}

// MARK: - DeletedBubble
// Shows in place of a message that was deleted (locally tracked)
private struct DeletedBubble: View {
    let isOutgoing: Bool
    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 48) }
            HStack(spacing: 5) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.onSurfaceMut.opacity(0.5))
                Text(isOutgoing ? "Вы удалили это сообщение" : "Сообщение удалено")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.onSurfaceMut.opacity(0.55))
                    .italic()
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color(red:0.09,green:0.10,blue:0.15).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.onSurfaceMut.opacity(0.12), lineWidth: 0.5))
            if !isOutgoing { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 8)
    }
}
