import SwiftUI
import PhotosUI

struct ChatView: View {
    let peerId:   Int
    let peerName: String

    @State private var messages:    [VKMessage] = []
    @State private var draft        = ""
    @State private var isLoading    = false
    @State private var isSending    = false
    @State private var myId         = 0
    @State private var showAttachPicker = false
    @State private var photoPickerItem: PhotosPickerItem? = nil

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if isLoading {
                    Spacer(); ProgressView().tint(.cyberBlue); Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(messages.reversed()) { msg in
                                    BubbleView(msg: msg, myId: myId).id(msg.id)
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
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .confirmationDialog("Прикрепить", isPresented: $showAttachPicker, titleVisibility: .visible) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label("Фото из галереи", systemImage: "photo")
            }
            Button("Файл") { /* TODO: document picker */ }
            Button("Аудио") { /* TODO: audio picker */ }
            Button("Отмена", role: .cancel) {}
        }
        .onChange(of: photoPickerItem) { _, item in
            guard item != nil else { return }
            // TODO: upload photo then send as attachment
            photoPickerItem = nil
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Attach button
            Button { showAttachPicker = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.onSurfaceMut)
                    .frame(width: 36, height: 36)
            }

            // Text field
            TextField("Сообщение...", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.surfaceVar)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(Color.onSurface)
                .font(.system(size: 15))

            // Send button
            Button { Task { await send() } } label: {
                if isSending {
                    ProgressView().tint(.cyberBlue).frame(width: 34, height: 34)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            draft.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.onSurfaceMut : Color.cyberBlue
                        )
                }
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.surface)
    }

    private func load() async {
        isLoading = true
        if let me = try? await VKAPIClient.shared.getProfile() { myId = me.id }
        messages = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? []
        isLoading = false
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true; draft = ""
        do {
            _ = try await VKAPIClient.shared.sendMessage(peerId: peerId, text: text)
            messages = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? messages
        } catch {
            draft = text // restore on failure
        }
        isSending = false
    }
}

private struct BubbleView: View {
    let msg:  VKMessage
    let myId: Int

    private var isMe: Bool { msg.fromId == myId }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMe { Spacer(minLength: 56) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                // Attachments
                if let attachments = msg.attachments, !attachments.isEmpty {
                    attachmentView(attachments)
                }

                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.system(size: 15))
                        .foregroundStyle(isMe ? Color.background : Color.onSurface)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMe ? Color.cyberBlue : Color.surfaceVar)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius:     isMe ? 16 : 4,
                            bottomLeadingRadius:  16,
                            bottomTrailingRadius: isMe ? 4 : 16,
                            topTrailingRadius:    16
                        ))
                }

                // Time
                Text(timeStr(msg.date))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.onSurfaceMut)
                    .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 56) }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func attachmentView(_ attachments: [VKAttachment]) -> some View {
        ForEach(attachments.indices, id: \.self) { i in
            let a = attachments[i]
            if a.type == "photo", let url = a.photo?.maxUrl.flatMap(URL.init) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color.surfaceVar.overlay(ProgressView().scaleEffect(0.6))
                    }
                }
                .frame(maxWidth: 220, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if a.type == "doc", let doc = a.doc {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill").foregroundStyle(Color.cyberBlue)
                    Text(doc.title).font(.system(size: 13))
                        .foregroundStyle(isMe ? Color.background : Color.onSurface)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isMe ? Color.cyberBlue.opacity(0.8) : Color.surfaceVar)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if a.type == "audio_message", let vm = a.audioMessage {
                HStack(spacing: 8) {
                    Image(systemName: "waveform").foregroundStyle(Color.cyberBlue)
                    Text("\(vm.duration)с").font(.system(size: 13))
                        .foregroundStyle(isMe ? Color.background : Color.onSurface)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isMe ? Color.cyberBlue.opacity(0.8) : Color.surfaceVar)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func timeStr(_ ts: Int) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}
