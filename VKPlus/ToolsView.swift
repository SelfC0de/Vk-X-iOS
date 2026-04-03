import SwiftUI

struct ToolsView: View {
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    toolCard(title: "Remove Banned Users",
                             subtitle: "Удалить удалённые/заблокированные аккаунты из друзей",
                             icon: "person.badge.minus", color: Color.errorRed) { RemoveBannedView() }

                    toolCard(title: "Bypass Gift Anonymity",
                             subtitle: "Деанон отправителя анонимного подарка через API",
                             icon: "gift.fill", color: Color(r:0xFF,g:0xAB,b:0x40)) { GiftAnonymityView() }

                    toolCard(title: "Currency Exchange",
                             subtitle: "Актуальные курсы 20 валют онлайн",
                             icon: "dollarsign.arrow.circlepath", color: Color(r:0xFF,g:0xD7,b:0x00)) { CurrencyExchangeView() }

                    // Bypass section — info cards
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🔓 Bypass").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.onSurfaceMut)
                        VStack(spacing: 0) {
                            bypassRow(icon: "doc.on.doc.fill",    title: "Bypass Copy + Reposts",   desc: "Долгое нажатие на сообщение копирует текст",             active: true)
                            Divider().background(Color.divider).padding(.leading, 48)
                            bypassRow(icon: "checkmark.message.fill", title: "Read Receipts",       desc: "Голосование в анонимных опросах без отображения имени", active: true)
                            Divider().background(Color.divider).padding(.leading, 48)
                            bypassRow(icon: "mic.slash.fill",     title: "Silent VM Listener",      desc: "Прослушивание ГС без markAsListened",                    active: true)
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.divider, lineWidth: 0.5))
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Инструменты").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func toolCard<Dest: View>(title: String, subtitle: String, icon: String, color: Color, dest: () -> Dest) -> some View {
        NavigationLink(destination: dest()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.onSurface)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill").foregroundStyle(color.opacity(0.6)).font(.system(size: 20))
            }
            .padding(16)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func bypassRow(icon: String, title: String, desc: String, active: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.cyberBlue).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Color.onSurface).font(.system(size: 14, weight: .medium))
                Text(desc).foregroundStyle(Color.onSurfaceMut).font(.system(size: 11))
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(r:0x4C,g:0xAF,b:0x50)).font(.system(size: 16))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// MARK: - Gift Anonymity
struct GiftAnonymityView: View {
    @State private var result  = ""; @State private var loading = false; @State private var done = false
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "gift.fill").font(.system(size: 40)).foregroundStyle(Color(r:0xFF,g:0xAB,b:0x40))
                        Text("Bypass Gift Anonymity").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.onSurface)
                        Text("Деанон отправителя анонимного подарка через API gifts.get")
                            .font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut).multilineTextAlignment(.center)
                    }
                    .padding(20).frame(maxWidth: .infinity).background(Color.surface).clipShape(RoundedRectangle(cornerRadius: 16))

                    if loading {
                        HStack(spacing: 10) {
                            ProgressView().tint(Color(r:0xFF,g:0xAB,b:0x40))
                            Text("Запрашиваем подарки...").foregroundStyle(Color.onSurfaceMut)
                        }.padding(16).background(Color.surface).clipShape(RoundedRectangle(cornerRadius: 14))
                    } else if !result.isEmpty {
                        Text(result).font(.system(size: 13, design: .monospaced)).foregroundStyle(Color.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16).background(Color.surface).clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        loading = true; result = ""
                        Task { result = (try? await VKAPIClient.shared.scanGifts()) ?? "Ошибка"; loading = false }
                    } label: {
                        Label("Сканировать подарки", systemImage: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.background)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Color(r:0xFF,g:0xAB,b:0x40)).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(loading)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle").foregroundStyle(Color.onSurfaceMut).font(.system(size: 12))
                        Text("Работает только если API вернул from_id в ответе (старые подарки)")
                            .font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Gift Anonymity").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
