import SwiftUI

struct ChatView: View {
    let peerId:   Int
    let peerName: String

    @State private var messages: [VKMessage] = []
    @State private var draft     = ""
    @State private var isLoading = false
    @State private var myId      = 0

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView().tint(.cyberBlue)
                    Spacer()
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

                // Input bar
                HStack(spacing: 10) {
                    TextField("Сообщение...", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.surfaceVar)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .foregroundStyle(Color.onSurface)
                        .font(.system(size: 15))

                    Button {
                        // TODO: send message
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(
                                draft.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.onSurfaceMut : Color.cyberBlue
                            )
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.surface)
            }
        }
        .navigationTitle(peerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        messages = (try? await VKAPIClient.shared.getMessages(peerId: peerId)) ?? []
        isLoading = false
    }
}

private struct BubbleView: View {
    let msg:  VKMessage
    let myId: Int

    private var isMe: Bool { msg.fromId == myId }

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 64) }
            Text(msg.text.isEmpty ? "📎" : msg.text)
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
            if !isMe { Spacer(minLength: 64) }
        }
    }
}
