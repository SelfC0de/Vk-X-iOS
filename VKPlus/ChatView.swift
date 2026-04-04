import SwiftUI
import PhotosUI

// MARK: - ChatView
struct ChatView: View {
    let peerId:   Int
    let peerName: String

    @State private var messages:     [VKMessage] = []
    @State private var draft         = ""
    @State private var isLoading     = false
    @State private var isSending     = false
    @State private var myId          = 0
    @State private var showAttach    = false
    @State private var photoItem:    PhotosPickerItem? = nil

    // Edit mode
    @State private var editingMsg:   VKMessage? = nil
    // Reply mode
    @State private var replyMsg:     VKMessage? = nil

    var body: some View {
        ZStack {
            Color(red:0.04,green:0.05,blue:0.09).ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading {
                    Spacer(); ProgressView().tint(.cyberBlue); Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(messages.reversed()) { msg in
                                    BubbleView(
                                        msg:      msg,
                                        myId:     myId,
                                        allMsgs:  messages,
                                        onReply:  { replyMsg = msg },
                                        onEdit:   { if msg.fromId == myId { editingMsg = msg; draft = msg.text } },
                                        onDelete: { Task { await deleteMsg(msg) } }
                                    )
                                    .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
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
        .navigationTitle(peerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red:0.05,green:0.06,blue:0.10), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .confirmationDialog("Прикрепить", isPresented: $showAttach, titleVisibility: .visible) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Фото из галереи", systemImage: "photo")
            }
            Button("Отмена", role: .cancel) {}
        }
        .onChange(of: photoItem) { _, item in
            guard item != nil else { return }
            photoItem = nil
        }
    }

    // MARK: - Input bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Reply banner
            if let r = replyMsg {
                replyBanner(r)
            }
            // Edit banner
            if let e = editingMsg {
                editBanner(e)
            }

            HStack(spacing: 8) {
                Button { showAttach = true } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red:0.4,green:0.5,blue:0.65))
                        .frame(width: 36, height: 36)
                }

                TextField(editingMsg != nil ? "Редактировать..." : "Сообщение...",
                          text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red:0.08,green:0.09,blue:0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .foregroundStyle(.white)
                    .font(.system(size: 15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                editingMsg != nil
                                    ? Color.cyberBlue.opacity(0.5)
                                    : replyMsg != nil
                                        ? Color(red:0.5,green:0.4,blue:0.9).opacity(0.5)
                                        : Color.clear,
                                lineWidth: 0.8
                            )
                    )

                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView().tint(.cyberBlue).frame(width: 34, height: 34)
                    } else {
                        Image(systemName: editingMsg != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color(red:0.25,green:0.30,blue:0.40) : Color.cyberBlue)
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isSending)

                // Cancel edit/reply
                if editingMsg != nil || replyMsg != nil {
                    Button {
                        editingMsg = nil; replyMsg = nil; draft = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(red:0.4,green:0.5,blue:0.65))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red:0.05,green:0.06,blue:0.10))
        }
    }

    @ViewBuilder
    private func replyBanner(_ msg: VKMessage) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color(red:0.5,green:0.4,blue:0.9))
                .frame(width: 3)
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 1) {
                Text("Ответ")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red:0.5,green:0.4,blue:0.9))
                Text(msg.text.isEmpty ? "Вложение" : String(msg.text.prefix(60)))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red:0.6,green:0.7,blue:0.85))
                    .lineLimit(1)
            }
            Spacer()
            Button { replyMsg = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red:0.4,green:0.5,blue:0.65))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red:0.07,green:0.08,blue:0.13))
    }

    @ViewBuilder
    private func editBanner(_ msg: VKMessage) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.cyberBlue)
                .frame(width: 3)
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 1) {
                Text("Редактирование")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cyberBlue)
                Text(String(msg.text.prefix(60)))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red:0.6,green:0.7,blue:0.85))
                    .lineLimit(1)
            }
            Spacer()
            Button { editingMsg = nil; draft = "" } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red:0.4,green:0.5,blue:0.65))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red:0.07,green:0.08,blue:0.13))
    }

    // MARK: - Actions
    private func load() async {
        isLoading = true
        if let me = try? await VKAPIClient.shared.getProfile() { myId = me.id }
        messages = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? []
        isLoading = false
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true

        if let editing = editingMsg {
            // Edit mode
            do {
                try await VKAPIClient.shared.editMessage(peerId: peerId, messageId: editing.id, text: text)
                if let idx = messages.firstIndex(where: { $0.id == editing.id }) {
                    messages[idx] = VKMessage(
                        id: editing.id, fromId: editing.fromId, text: text,
                        date: editing.date, attachments: editing.attachments
                    )
                }
                ToastManager.shared.show("Сообщение изменено", icon: "pencil.circle.fill", style: .success)
            } catch {
                ToastManager.shared.show("Ошибка редактирования", icon: "exclamationmark.triangle.fill", style: .warning)
            }
            editingMsg = nil
        } else {
            // Send mode
            let replyId = replyMsg?.id
            draft = ""
            replyMsg = nil
            do {
                _ = try await VKAPIClient.shared.sendMessage(peerId: peerId, text: text, replyTo: replyId)
                messages = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? messages
                ToastManager.shared.show("Отправлено", icon: "paperplane.fill", style: .success)
            } catch {
                draft = text
                ToastManager.shared.show("Ошибка отправки", icon: "exclamationmark.triangle.fill", style: .warning)
            }
        }

        isSending = false
        draft = ""
    }

    private func deleteMsg(_ msg: VKMessage) async {
        do {
            try await VKAPIClient.shared.deleteMessage(messageIds: [msg.id])
            withAnimation { messages.removeAll { $0.id == msg.id } }
            ToastManager.shared.show("Удалено", icon: "trash.fill", style: .info)
        } catch {
            ToastManager.shared.show("Ошибка удаления", icon: "exclamationmark.triangle.fill", style: .warning)
        }
    }
}

// MARK: - BubbleView
private struct BubbleView: View {
    let msg:      VKMessage
    let myId:     Int
    let allMsgs:  [VKMessage]
    let onReply:  () -> Void
    let onEdit:   () -> Void
    let onDelete: () -> Void

    @State private var pressed = false

    private var isMe: Bool { msg.fromId == myId }

    // Colors
    private var myBubbleBg:    Color { Color(red:0.07,green:0.28,blue:0.52) }
    private var theirBubbleBg: Color { Color(red:0.10,green:0.12,blue:0.18) }
    private var myTextColor:   Color { Color(red:0.92,green:0.96,blue:1.00) }
    private var theirTextColor:Color { Color(red:0.88,green:0.90,blue:0.95) }
    private var myTimeColor:   Color { Color(red:0.55,green:0.75,blue:0.95) }
    private var theirTimeColor:Color { Color(red:0.40,green:0.45,blue:0.58) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                // Reply quote
                if let rid = msg.replyMessageId,
                   let quoted = allMsgs.first(where: { $0.id == rid }) {
                    quotedView(quoted)
                }

                // Attachments
                if let atts = msg.attachments, !atts.isEmpty {
                    attachmentsView(atts)
                }

                // Text body
                if !msg.text.isEmpty {
                    HStack(alignment: .bottom, spacing: 6) {
                        Text(msg.text)
                            .font(.system(size: 15))
                            .foregroundStyle(isMe ? myTextColor : theirTextColor)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(timeStr(msg.date))
                            .font(.system(size: 10))
                            .foregroundStyle(isMe ? myTimeColor : theirTimeColor)
                            .alignmentGuide(.bottom) { d in d[.bottom] }
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(isMe ? myBubbleBg : theirBubbleBg)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius:     isMe ? 18 : 4,
                        bottomLeadingRadius:  isMe ? 18 : 4,
                        bottomTrailingRadius: isMe ? 4  : 18,
                        topTrailingRadius:    18
                    ))
                    .overlay(
                        // subtle border
                        UnevenRoundedRectangle(
                            topLeadingRadius:     isMe ? 18 : 4,
                            bottomLeadingRadius:  isMe ? 18 : 4,
                            bottomTrailingRadius: isMe ? 4  : 18,
                            topTrailingRadius:    18
                        )
                        .stroke(
                            isMe
                                ? Color(red:0.15,green:0.45,blue:0.75).opacity(0.4)
                                : Color(red:0.25,green:0.28,blue:0.38).opacity(0.4),
                            lineWidth: 0.5
                        )
                    )
                }
                // Time when no text (only attachments)
                if msg.text.isEmpty {
                    Text(timeStr(msg.date))
                        .font(.system(size: 10))
                        .foregroundStyle(isMe ? myTimeColor : theirTimeColor)
                        .padding(.horizontal, 4)
                }
            }
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .contextMenu {
                Button { onReply() } label: { Label("Ответить", systemImage: "arrowshape.turn.up.left") }
                if isMe {
                    Button { onEdit() } label: { Label("Редактировать", systemImage: "pencil") }
                }
                Button(role: .destructive) { onDelete() } label: { Label("Удалить", systemImage: "trash") }
                Button {
                    UIPasteboard.general.string = msg.text
                    ToastManager.shared.show("Скопировано", icon: "doc.on.clipboard", style: .info)
                } label: { Label("Копировать", systemImage: "doc.on.doc") }
            }

            if !isMe { Spacer(minLength: 60) }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func quotedView(_ quoted: VKMessage) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(isMe ? Color(red:0.3,green:0.6,blue:1.0) : Color(red:0.5,green:0.4,blue:0.9))
                .frame(width: 2.5)
                .clipShape(Capsule())
            Text(quoted.text.isEmpty ? "Вложение" : String(quoted.text.prefix(50)))
                .font(.system(size: 12))
                .foregroundStyle(isMe ? Color(red:0.6,green:0.8,blue:1.0) : Color(red:0.65,green:0.60,blue:0.90))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isMe
            ? Color(red:0.05,green:0.18,blue:0.35)
            : Color(red:0.07,green:0.08,blue:0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func attachmentsView(_ atts: [VKAttachment]) -> some View {
        ForEach(atts.indices, id: \.self) { i in
            let a = atts[i]
            if a.type == "photo", let url = a.photo?.maxUrl.flatMap(URL.init) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color(red:0.08,green:0.10,blue:0.16).overlay(ProgressView().scaleEffect(0.6))
                    }
                }
                .frame(maxWidth: 220, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
            } else if a.type == "doc", let doc = a.doc {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill").foregroundStyle(Color.cyberBlue).font(.system(size: 14))
                    Text(doc.title).font(.system(size: 13)).foregroundStyle(isMe ? myTextColor : theirTextColor).lineLimit(1)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isMe ? myBubbleBg : theirBubbleBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if a.type == "audio_message", let vm = a.audioMessage {
                HStack(spacing: 8) {
                    Image(systemName: "waveform").foregroundStyle(Color.cyberBlue).font(.system(size: 14))
                    Text("\(vm.duration)с").font(.system(size: 13)).foregroundStyle(isMe ? myTextColor : theirTextColor)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isMe ? myBubbleBg : theirBubbleBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func timeStr(_ ts: Int) -> String {
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return df.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}
