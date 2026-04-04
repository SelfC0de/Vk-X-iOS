import SwiftUI

struct MessagesView: View {
    @State private var dialogs: [DialogItem] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            Group {
                if isLoading {
                    ProgressView().tint(.cyberBlue)
                } else if dialogs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 44)).foregroundStyle(Color.onSurfaceMut)
                        Text("Нет диалогов").foregroundStyle(Color.onSurfaceMut)
                    }
                } else {
                    List(dialogs) { dialog in
                        NavigationLink(destination: ChatView(peerId: dialog.id, peerName: dialog.name, peerAvatar: dialog.avatar)) {
                            DialogRow(dialog: dialog)
                        }
                        .listRowBackground(Color.surface)
                        .listRowSeparatorTint(Color.divider)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Сообщения")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                VStack(spacing: 0) {
                    GarlandView()
                    PetView()
                    ClockView().padding(.leading, 4)
                }
                .frame(width: 200, alignment: .leading)
            } }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        dialogs = (try? await VKAPIClient.shared.getDialogs()) ?? []
        isLoading = false
    }
}

private struct DialogRow: View {
    let dialog: DialogItem
    @ObservedObject private var settings = SettingsStore.shared
    private var displayName: String   { settings.hideSender ? "Пользователь скрыт" : dialog.name }
    private var displayAvatar: String? { settings.hideSender ? nil : dialog.avatar }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if settings.hideSender {
                    ZStack {
                        Circle().fill(Color.surfaceVar).frame(width: 48, height: 48)
                        Image(systemName: "person.fill.xmark")
                            .foregroundStyle(Color.onSurfaceMut).font(.system(size: 20))
                    }
                } else {
                    AvatarView(url: dialog.avatar, size: 48)
                    if dialog.isOnline {
                        Circle().fill(Color.cyberAccent).frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.surface, lineWidth: 2))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(displayName)
                        .foregroundStyle(settings.hideSender ? Color.onSurfaceMut : Color.onSurface)
                        .font(.system(size: 15, weight: settings.hideSender ? .regular : .medium)).lineLimit(1)
                    Spacer()
                    if dialog.unreadCount > 0 {
                        Text("\(dialog.unreadCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.background)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.cyberBlue).clipShape(Capsule())
                    }
                }
                Text(dialog.lastMessage.isEmpty ? "Нет сообщений" : dialog.lastMessage)
                    .foregroundStyle(Color.onSurfaceMut)
                    .font(.system(size: 13)).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
