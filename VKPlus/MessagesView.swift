import SwiftUI

struct MessagesView: View {
    @State private var dialogs:  [DialogItem] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [DialogItem] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return dialogs }
        let q = searchText.lowercased()
        return dialogs.filter {
            $0.name.lowercased().contains(q) ||
            $0.lastMessage.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.onSurfaceMut)
                        .font(.system(size: 15))
                    TextField("Поиск диалогов...", text: $searchText)
                        .foregroundStyle(Color.onSurface)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($searchFocused)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.onSurfaceMut)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.surfaceVar)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.surface)

                Group {
                    if isLoading {
                        Spacer()
                        ProgressView().tint(.cyberBlue)
                        Spacer()
                    } else if filtered.isEmpty && !searchText.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36)).foregroundStyle(Color.onSurfaceMut)
                            Text("Ничего не найдено")
                                .foregroundStyle(Color.onSurfaceMut)
                        }
                        Spacer()
                    } else if dialogs.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 44)).foregroundStyle(Color.onSurfaceMut)
                            Text("Нет диалогов").foregroundStyle(Color.onSurfaceMut)
                        }
                        Spacer()
                    } else {
                        List(filtered) { dialog in
                            NavigationLink(destination: ChatView(peerId: dialog.id, peerName: dialog.name, peerAvatar: dialog.avatar)) {
                                DialogRow(dialog: dialog)
                            }
                            .listRowBackground(Color.surface)
                            .listRowSeparatorTint(Color.divider)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.immediately)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) {
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
            } }
        .task { await load() }
        .task(id: UUID()) {
            // Periodic background refresh every 5s
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await fetchDialogs()
            }
        }
        .refreshable { await refresh() }
    }

    private func load() async {
        isLoading = true
        await fetchDialogs()
        isLoading = false
    }

    private func updateBadge() {
        let total = dialogs.reduce(0) { $0 + $1.unreadCount }
        Task { @MainActor in UnreadCountManager.shared.count = total }
    }

    private func fetchDialogs() async {
        // Keep existing on error
        if let fresh = try? await VKAPIClient.shared.getDialogs(), !fresh.isEmpty {
            dialogs = fresh
            updateBadge()
        } else if dialogs.isEmpty {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if let retry = try? await VKAPIClient.shared.getDialogs() {
                dialogs = retry
                updateBadge()
            }
        }
    }

    private func refresh() async {
        if let fresh = try? await VKAPIClient.shared.getDialogs(), !fresh.isEmpty {
            dialogs = fresh
        }
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
