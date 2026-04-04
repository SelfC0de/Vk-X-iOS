import SwiftUI
import PhotosUI

// MARK: - ChatView
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
    @State private var photoItem:  PhotosPickerItem? = nil
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
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.first {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
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
                    AvatarView(url: peerAvatar, size: 32)
                        .overlay(Circle().stroke(Color.cyberBlue.opacity(0.3), lineWidth: 0.8))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(peerName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.onSurface)
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
        .toolbarBackground(Color(red:0.05,green:0.06,blue:0.10), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .confirmationDialog("Прикрепить", isPresented: $showAttach, titleVisibility: .visible) {
            PhotosPicker(selection: $photoItem, matching: .images) { Label("Фото из галереи", systemImage: "photo") }
            Button("Отмена", role: .cancel) {}
        }
        .onChange(of: photoItem) { _, _ in photoItem = nil }
    }

    // MARK: - Input bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            if let r = replyMsg   { replyBanner(r)  }
            if let e = editingMsg { editBanner(e)   }

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
            let replyId = replyMsg?.id; draft = ""; replyMsg = nil
            do {
                _ = try await VKAPIClient.shared.sendMessage(peerId: peerId, text: text, replyTo: replyId)
                messages = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? messages
                ToastManager.shared.show("Отправлено", icon: "paperplane.fill", style: .success)
            } catch { draft = text; ToastManager.shared.show("Ошибка", icon: "exclamationmark.triangle.fill", style: .warning) }
        }
        isSending = false; draft = ""
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
                AvatarView(url: avatarMap[msg.fromId], size: AV)
                    .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    .frame(width: AV)
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
                        Text(msg.text)
                            .font(.system(size: 15))
                            .foregroundStyle(fg)
                            .multilineTextAlignment(.leading)
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
        ForEach(atts.indices, id: \.self) { i in
            let a = atts[i]
            if a.type == "photo", let url = a.photo?.maxUrl.flatMap(URL.init) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().scaledToFill() }
                    else { Color(red:0.08,green:0.10,blue:0.16) }
                }
                .frame(maxWidth: min(maxW, 220), maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if a.type == "doc", let doc = a.doc {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill").foregroundStyle(Color.cyberBlue).font(.system(size: 13))
                    Text(doc.title).font(.system(size: 13)).foregroundStyle(fg).lineLimit(1)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(bg).clipShape(RoundedRectangle(cornerRadius: 9))
            } else if a.type == "audio_message", let vm = a.audioMessage {
                HStack(spacing: 6) {
                    Image(systemName: "waveform").foregroundStyle(Color.cyberBlue).font(.system(size: 13))
                    Text("\(vm.duration)с").font(.system(size: 13)).foregroundStyle(fg)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(bg).clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private func timeStr(_ ts: Int) -> String {
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return df.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}
