import SwiftUI
import PhotosUI

// MARK: - ChatView
struct ChatView: View {
    let peerId:    Int
    let peerName:  String
    var peerAvatar: String? = nil
    @ObservedObject private var settings = SettingsStore.shared

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
    @State private var videoItem2:  PhotosPickerItem? = nil
    @State private var audioItem:   PhotosPickerItem? = nil
    @State private var showFilePicker = false
    @State private var pendingAttach: String? = nil
    @State private var isUploading   = false
    @State private var editingMsg: VKMessage? = nil
    @State private var replyMsg:   VKMessage? = nil
    @State private var peerOnline  = false
    @State private var peerTyping  = false
    @State private var typingTimer: Timer? = nil

    // Screen width for bubble sizing
    private var W: CGFloat { UIScreen.main.bounds.width }
    // Avatar slot width
    private let AV: CGFloat = 28
    // Max bubble width: ~72% of screen minus avatar slots
    private var maxW: CGFloat { (W - (AV+6)*2 - 20) * 0.72 }

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
                                ForEach(messages.reversed()) { msg in
                                    BubbleView(
                                        msg:      msg,
                                        myId:     myId,
                                        allMsgs:  messages,
                                        avatarMap: avatarMap,
                                        myAvatar:  myAvatar,
                                        maxW:      maxW,
                                        onReply:  { replyMsg = msg },
                                        onEdit:   { if msg.fromId == myId { editingMsg = msg; draft = msg.text } },
                                        onDelete: { Task { await deleteMsg(msg) } }
                                    )
                                    .id(msg.id)
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
                    if settings.hideSender {
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
                        Text(settings.hideSender ? "Пользователь скрыт" : peerName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(settings.hideSender ? Color.onSurfaceMut : Color.onSurface)
                        if !settings.hideSender {
                            if peerTyping { TypingStatusView() }
                            else {
                                Text(peerOnline ? "в сети" : "не в сети")
                                    .font(.system(size: 11))
                                    .foregroundStyle(peerOnline ? Color.cyberAccent : Color.onSurfaceMut)
                            }
                        }
                    }
                }
            }
        }
        .toolbarBackground(Color(red:0.05,green:0.06,blue:0.10), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .confirmationDialog("Прикрепить", isPresented: $showAttach, titleVisibility: .visible) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Фото", systemImage: "photo")
            }
            PhotosPicker(selection: $videoItem2, matching: .videos) {
                Label("Видео", systemImage: "video")
            }
            Button("Документ / Файл") { showFilePicker = true }
            Button("Отмена", role: .cancel) {}
        }
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
        // Uploading toast overlay
        .overlay(alignment: .top) {
            if isUploading {
                HStack(spacing: 8) {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text("Загрузка...").font(.system(size: 13)).foregroundStyle(.white)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.cyberBlue.opacity(0.9))
                .clipShape(Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Input bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            if let r = replyMsg   { replyBanner(r)  }
            if let e = editingMsg { editBanner(e)   }
            if let a = pendingAttach { attachBanner(a) }

            HStack(spacing: 8) {
                Button { showAttach = true } label: {
                    Image(systemName: "paperclip").font(.system(size: 20))
                        .foregroundStyle(Color(red:0.4,green:0.5,blue:0.65))
                        .frame(width: 36, height: 36)
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
                    .onChange(of: draft) { _, v in if !v.isEmpty { simulateTyping() } }

                Button { Task { await send() } } label: {
                    if isSending { ProgressView().tint(.cyberBlue).frame(width: 34, height: 34) }
                    else {
                        Image(systemName: editingMsg != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color(red:0.25,green:0.30,blue:0.40) : Color.cyberBlue)
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isSending)

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
        HStack(spacing: 8) {
            Rectangle().fill(Color(red:0.5,green:0.4,blue:0.9)).frame(width: 3).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 1) {
                Text("Ответ").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(red:0.5,green:0.4,blue:0.9))
                Text(msg.text.isEmpty ? "Вложение" : String(msg.text.prefix(60)))
                    .font(.system(size: 12)).foregroundStyle(Color(red:0.6,green:0.7,blue:0.85)).lineLimit(1)
            }
            Spacer()
            Button { replyMsg = nil } label: { Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(Color(red:0.4,green:0.5,blue:0.65)) }
        }
        .padding(.horizontal, 14).padding(.vertical, 8).background(Color(red:0.07,green:0.08,blue:0.13))
    }

    @ViewBuilder private func attachBanner(_ att: String) -> some View {
        HStack(spacing: 8) {
            let icon = att.hasPrefix("photo") ? "photo.fill" :
                       att.hasPrefix("video") ? "video.fill" :
                       att.hasPrefix("audio") ? "waveform" : "paperclip"
            Rectangle().fill(Color(red:0.0,green:0.7,blue:0.5)).frame(width: 3).clipShape(Capsule())
            Image(systemName: icon).foregroundStyle(Color(red:0.0,green:0.7,blue:0.5)).font(.system(size: 13))
            Text("Вложение прикреплено").font(.system(size: 13)).foregroundStyle(Color.onSurface)
            Spacer()
            Button { pendingAttach = nil } label: {
                Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(red:0.07,green:0.08,blue:0.13))
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
    private func load() async {
        isLoading = true
        if let me = try? await VKAPIClient.shared.getProfile() { myId = me.id; myAvatar = me.photo100 }
        messages = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? []
        if peerId > 0, let user = try? await VKAPIClient.shared.getUserById("\(peerId)") { peerOnline = user.isOnline }
        let ids = Array(Set(messages.map { $0.fromId }.filter { $0 != myId && $0 > 0 }))
        if !ids.isEmpty, let users = try? await VKAPIClient.shared.getUsers(ids: ids.map(String.init).joined(separator: ",")) {
            for u in users { avatarMap[u.id] = u.photo100 }
        }
        isLoading = false
    }

    private func simulateTyping() {
        peerTyping = true; typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in peerTyping = false }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces); guard !text.isEmpty else { return }
        isSending = true
        if let editing = editingMsg {
            do {
                try await VKAPIClient.shared.editMessage(peerId: peerId, messageId: editing.id, text: text)
                if let idx = messages.firstIndex(where: { $0.id == editing.id }) {
                    messages[idx] = VKMessage(id: editing.id, fromId: editing.fromId, text: text,
                                              date: editing.date, replyMessageId: editing.replyMessageId, attachments: editing.attachments)
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
    @State private var phases: [CGFloat] = [0, 0, 0]
    @State private var step = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            Text("Печатает").font(.system(size: 11)).foregroundStyle(Color.cyberBlue)
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
    let allMsgs:   [VKMessage]
    let avatarMap: [Int: String]
    let myAvatar:  String?
    let maxW:      CGFloat
    let onReply:   () -> Void
    let onEdit:    () -> Void
    let onDelete:  () -> Void

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
                // Reply quote
                if let rid = msg.replyMessageId,
                   let q = allMsgs.first(where: { $0.id == rid }) {
                    quotedView(q)
                }
                // Attachments
                if let atts = msg.attachments, !atts.isEmpty {
                    attachmentsView(atts)
                }
                // Text
                if !msg.text.isEmpty {
                    HStack(alignment: .bottom, spacing: 5) {
                        MessageTextView(
                            text: msg.text,
                            textColor: fg
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        Text(timeStr(msg.date))
                            .font(.system(size: 10))
                            .foregroundStyle(tc)
                            .layoutPriority(-1)
                            .alignmentGuide(.bottom) { d in d[.bottom] }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(bg)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius:     isMe ? 16 : 4,
                        bottomLeadingRadius:  isMe ? 16 : 4,
                        bottomTrailingRadius: isMe ?  4 : 16,
                        topTrailingRadius:    16))
                    .overlay(UnevenRoundedRectangle(
                        topLeadingRadius:     isMe ? 16 : 4,
                        bottomLeadingRadius:  isMe ? 16 : 4,
                        bottomTrailingRadius: isMe ?  4 : 16,
                        topTrailingRadius:    16)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5))
                }
                if msg.text.isEmpty {
                    Text(timeStr(msg.date)).font(.system(size: 10)).foregroundStyle(tc).padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: maxW, alignment: isMe ? .trailing : .leading)
            .contextMenu {
                Button { onReply() } label: { Label("Ответить", systemImage: "arrowshape.turn.up.left") }
                if isMe { Button { onEdit() } label: { Label("Редактировать", systemImage: "pencil") } }
                Button(role: .destructive) { onDelete() } label: { Label("Удалить", systemImage: "trash") }
                Button {
                    UIPasteboard.general.string = msg.text
                    ToastManager.shared.show("Скопировано", icon: "doc.on.clipboard", style: .info)
                } label: { Label("Копировать", systemImage: "doc.on.doc") }
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

    @ViewBuilder private func quotedView(_ q: VKMessage) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(isMe ? Color.cyberBlue : Color(red:0.5,green:0.4,blue:0.9))
                .frame(width: 2).clipShape(Capsule())
            Text(q.text.isEmpty ? "Вложение" : String(q.text.prefix(50)))
                .font(.system(size: 12))
                .foregroundStyle(isMe ? Color(red:0.6,green:0.8,blue:1.0) : Color(red:0.65,green:0.60,blue:0.90))
                .lineLimit(2)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(isMe ? Color(red:0.05,green:0.18,blue:0.35) : Color(red:0.07,green:0.08,blue:0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func attachmentsView(_ atts: [VKAttachment]) -> some View {
        // Collect all photos for gallery view
        let photoUrls = atts.filter { $0.type == "photo" }.compactMap { $0.photo?.maxUrl }
        ForEach(atts.indices, id: \.self) { i in
            let a = atts[i]
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
                }

            case "audio":
                if let au = a.audio, let url = au.url {
                    AudioPlayerView(url: url, duration: au.duration ?? 0, isVoice: false)
                        .frame(maxWidth: min(maxW, 240))
                        .background(bg)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
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

            default:
                EmptyView()
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
private struct MessageTextView: View {
    let text: String
    let textColor: Color
    var onVKLink: ((String) -> Void)? = nil
    var onURL: ((URL) -> Void)? = nil

    @State private var vkProfileName: String = ""
    @State private var showVKProfile = false

    var body: some View {
        LinkableText(
            text: text,
            textColor: textColor,
            onVKLink: { name in
                vkProfileName = name
                showVKProfile = true
            },
            onURL: { url in UIApplication.shared.open(url) }
        )
        .sheet(isPresented: $showVKProfile) {
            VKProfileResolverSheet(screenName: vkProfileName)
        }
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

// MARK: - VK Profile resolver sheet
private struct VKProfileResolverSheet: View {
    let screenName: String
    @Environment(\.dismiss) var dismiss
    @State private var user: VKUser? = nil
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(.cyberBlue)
                } else if let user {
                    FriendProfileView(user: user)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash").font(.system(size: 44)).foregroundStyle(Color.onSurfaceMut)
                        Text("Профиль не найден").foregroundStyle(Color.onSurfaceMut)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .toolbarBackground(Color.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        // getUserById accepts: numeric id, "id123", screen_name — all in one call
        user = try? await VKAPIClient.shared.getUserById(screenName)
        isLoading = false
    }
}
