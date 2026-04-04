import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var settings = SettingsStore.shared
    @State private var user: VKUser?
    @State private var isLoading  = false
    @State private var mirror     = MirrorProfile()
    @State private var showMirrorSheet = false
    @State private var headerAppeared = false
    @State private var fetchedVerifInfo: VKVerificationInfo? = nil

    private var displayName:  String   { mirror.isActive && !mirror.name.isEmpty  ? mirror.name  : (user?.fullName ?? "") }
    private var displayPhoto: String?  { mirror.isActive && !mirror.photo.isEmpty ? mirror.photo : user?.avatar }
    private var displayStatus: String? { mirror.isActive ? (mirror.status.isEmpty ? nil : mirror.status) : user?.status }
    private var displayCity:  String?  { mirror.isActive && !mirror.city.isEmpty  ? mirror.city  : user?.city?.title }
    private var displayLink:  String {
        if mirror.isActive {
            if !mirror.screenName.isEmpty { return "vk.com/\(mirror.screenName)" }
            if mirror.id > 0 { return "vk.com/id\(mirror.id)" }
        }
        return "vk.com/id\(user?.id ?? 0)"
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.cyberBlue)
            } else if let u = user {
                profileContent(u)
            } else {
                errorState
            }
        }
        .navigationTitle("Профиль").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Color.cyberBlue)
                }
            }
        }
        .sheet(isPresented: $showMirrorSheet) { ProfileChangerSheet(mirror: $mirror) }
        .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                VStack(spacing: 0) {
                    GarlandView()
                    PetView()
                    ClockView().padding(.leading, 4)
                }
                .frame(width: 200, alignment: .leading)
            } }
        .task { await load() }
        .onChange(of: settings.verifyChecker) { _, on in
            if on, let uid = user?.id {
                Task { @MainActor in
                    fetchedVerifInfo = try? await VKAPIClient.shared.getUserVerification(userId: uid)
                }
            }
        }
    }

    @ViewBuilder
    private func profileContent(_ u: VKUser) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // ── Hero header ──────────────────────────────────────────
                heroHeader(u)

                // ── Info cards ──────────────────────────────────────────
                VStack(spacing: 12) {
                    // Stats row
                    if let followers = u.followersCount, followers > 0 {
                        statsRow(followers: followers)
                    }

                    // About card
                    aboutCard(u)

                    // Actions
                    actionsRow(u)

                    // Profile history
                    ProfileHistorySection()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private func heroHeader(_ u: VKUser) -> some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                colors: [
                    mirror.isActive ? Color(r:0xFF,g:0x6B,b:0x35).opacity(0.6) : Color.cyberBlue.opacity(0.25),
                    Color.background
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 200)
            .overlay(
                // Subtle grid pattern
                Canvas { ctx, size in
                    let spacing: CGFloat = 30
                    var x: CGFloat = 0
                    while x < size.width {
                        var y: CGFloat = 0
                        while y < size.height {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                                     with: .color(Color.cyberBlue.opacity(0.12)))
                            y += spacing
                        }
                        x += spacing
                    }
                }
            )

            VStack(spacing: 0) {
                // Avatar with glow
                ZStack {
                    // Glow ring
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (mirror.isActive ? Color(r:0xFF,g:0x6B,b:0x35) : Color.cyberBlue).opacity(0.4),
                                    Color.clear
                                ],
                                center: .center, startRadius: 44, endRadius: 64
                            )
                        )
                        .frame(width: 128, height: 128)

                    AvatarView(url: displayPhoto, size: 88)
                        .overlay(
                            Circle().stroke(
                                mirror.isActive
                                    ? LinearGradient(colors: [Color(r:0xFF,g:0x6B,b:0x35), Color(r:0xFF,g:0xAB,b:0x40)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.cyberBlue, Color.cyberAccent], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 3
                            )
                        )
                        .shadow(color: (mirror.isActive ? Color(r:0xFF,g:0x6B,b:0x35) : Color.cyberBlue).opacity(0.5), radius: 12)

                    // Verification badge
                    if settings.fakeVerification || u.verified == 1 {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.cyberBlue)
                            .font(.system(size: 22))
                            .background(Circle().fill(Color.background).frame(width: 24, height: 24))
                            .offset(x: 30, y: 30)
                    }

                    // Mirror indicator
                    if mirror.isActive {
                        Text("🎭")
                            .font(.system(size: 18))
                            .offset(x: -30, y: 30)
                    }
                }
                .padding(.bottom, 12)

                // Name
                Text(displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(mirror.isActive ? Color(r:0xFF,g:0x6B,b:0x35) : Color.onSurface)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Status
                if let status = displayStatus, !status.isEmpty {
                    Text(status)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.onSurfaceMut)
                        .padding(.top, 4)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                // Link
                HStack(spacing: 4) {
                    Image(systemName: "link").font(.system(size: 11))
                    Text(displayLink).font(.system(size: 12))
                }
                .foregroundStyle(Color.cyberBlue)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
        }
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                headerAppeared = true
            }
        }
    }

    @ViewBuilder
    private func statsRow(followers: Int) -> some View {
        HStack(spacing: 1) {
            statItem(value: formatNum(followers), label: "Подписчики")
            Divider().background(Color.divider).frame(height: 30)
            statItem(value: u_online(user), label: "Статус")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.divider, lineWidth: 0.5))
    }

    @ViewBuilder
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.onSurface)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func aboutCard(_ u: VKUser) -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Label("Информация", systemImage: "person.text.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.onSurfaceMut)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            // Rows
            infoRow(icon: "number", label: "ID",
                    value: mirror.isActive && mirror.id > 0 ? "\(mirror.id)" : "\(u.id)")
            divider
            infoRow(icon: "link", label: "Страница", value: displayLink)
            if let city = displayCity {
                divider
                infoRow(icon: "mappin.and.ellipse", label: "Город", value: city)
            }
            if let bdate = u.bdate {
                divider
                infoRow(icon: "gift", label: "Дата рождения", value: bdate)
            }
            if settings.verifyChecker {
                divider
VerificationRowFetched(
                                    user: u,
                                    fetchedInfo: fetchedVerifInfo,
                                    fakeVerif: settings.fakeVerification
                                )
            }
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.divider, lineWidth: 0.5))
    }

    @ViewBuilder
    private func actionsRow(_ u: VKUser) -> some View {
        VStack(spacing: 10) {
            // Copy profile link
            Button {
                let link = "https://vk.com/id\(u.id)"
                UIPasteboard.general.string = link
                ToastManager.shared.show("Ссылка скопирована", icon: "link", style: .success)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link").font(.system(size: 16))
                    Text("Скопировать ссылку на профиль").font(.system(size: 15, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(Color.onSurface)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.surfaceVar)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.divider, lineWidth: 1))
            }

            // Profile Changer button
            Button {
                if mirror.isActive { mirror = MirrorProfile() }
                else { showMirrorSheet = true }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: mirror.isActive ? "xmark.circle.fill" : "person.crop.circle.badge.questionmark.fill")
                        .font(.system(size: 16))
                    Text(mirror.isActive ? "Сбросить Profile Changer" : "Profile Changer")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12))
                }
                .foregroundStyle(mirror.isActive ? Color.errorRed : Color.cyberBlue)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background((mirror.isActive ? Color.errorRed : Color.cyberBlue).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                    (mirror.isActive ? Color.errorRed : Color.cyberBlue).opacity(0.3), lineWidth: 1))
            }

            // Logout
            Button { authVM.logout() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 16))
                    Text("Выйти из аккаунта").font(.system(size: 15, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(Color.errorRed)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.errorRed.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.errorRed.opacity(0.3), lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.cyberBlue).frame(width: 20)
            Text(label).foregroundStyle(Color.onSurfaceMut).font(.system(size: 13))
            Spacer()
            Text(value).foregroundStyle(Color.onSurface).font(.system(size: 13)).lineLimit(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    private var divider: some View {
        Divider().background(Color.divider).padding(.leading, 48)
    }

    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 56)).foregroundStyle(Color.onSurfaceMut.opacity(0.4))
            Text("Не удалось загрузить профиль").foregroundStyle(Color.onSurfaceMut)
            Button {
                Task { await load() }
            } label: {
                Text("Повторить").foregroundStyle(Color.background)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.cyberBlue).clipShape(Capsule())
            }
        }
    }

    private func load() async {
        isLoading = true
        user = try? await VKAPIClient.shared.getProfile()
        isLoading = false
        // Fetch fresh verification via execute+Android UA if checker enabled
        if settings.verifyChecker, let uid = user?.id {
            fetchedVerifInfo = try? await VKAPIClient.shared.getUserVerification(userId: uid)
        }
    }

    private func formatNum(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    private func u_online(_ u: VKUser?) -> String {
        guard let u else { return "—" }
        return u.isOnline ? "Онлайн" : "Не в сети"
    }
}

// ProfileChangerSheet
struct ProfileChangerSheet: View {
    @Binding var mirror: MirrorProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.questionmark.fill")
                                .font(.system(size: 40)).foregroundStyle(Color.cyberBlue)
                            Text("Profile Changer")
                                .font(.system(size: 18, weight: .bold)).foregroundStyle(Color.onSurface)
                            Text("Введите ID пользователя для подмены данных профиля")
                                .font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Input
                        TextField("User ID или @username", text: $mirror.userId)
                            .padding(14).background(Color.surfaceVar)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.onSurface)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.divider, lineWidth: 1))

                        if let err = mirror.error {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.errorRed)
                                Text(err).font(.system(size: 12)).foregroundStyle(Color.errorRed)
                            }
                        }

                        // Preview card
                        if !mirror.name.isEmpty {
                            HStack(spacing: 12) {
                                AvatarView(url: mirror.photo.isEmpty ? nil : mirror.photo, size: 52)
                                    .overlay(Circle().stroke(Color.cyberBlue, lineWidth: 1.5))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mirror.name).foregroundStyle(Color.onSurface)
                                        .font(.system(size: 15, weight: .semibold))
                                    if !mirror.city.isEmpty {
                                        Label(mirror.city, systemImage: "mappin")
                                            .font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                                    }
                                    if !mirror.status.isEmpty {
                                        Text(mirror.status).font(.system(size: 12))
                                            .foregroundStyle(Color.onSurfaceMut).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(r:0x4C,g:0xAF,b:0x50)).font(.system(size: 20))
                            }
                            .padding(14)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyberBlue.opacity(0.3), lineWidth: 1))
                        }

                        // Load button
                        Button { Task { await loadMirror() } } label: {
                            ZStack {
                                if mirror.isLoading { ProgressView().tint(Color.background) }
                                else {
                                    Label(mirror.name.isEmpty ? "Загрузить профиль" : "Обновить",
                                          systemImage: "arrow.down.circle.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.background)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(mirror.userId.isEmpty ? Color.cyberBlue.opacity(0.4) : Color.cyberBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(mirror.userId.isEmpty || mirror.isLoading)

                        if !mirror.name.isEmpty {
                            Button {
                                mirror.isActive = true
                                dismiss()
                            } label: {
                                Label("Применить подмену", systemImage: "theatermasks.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.background)
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(Color(r:0xFF,g:0x6B,b:0x35))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Profile Changer").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }.foregroundStyle(Color.cyberBlue)
                }
            }
        }
    }

    private func loadMirror() async {
        mirror.isLoading = true; mirror.error = nil
        do {
            let u = try await VKAPIClient.shared.getUserById(mirror.userId)
            mirror.name = u.fullName; mirror.photo = u.avatar ?? ""
            mirror.status = u.status ?? ""; mirror.city = u.city?.title ?? ""; mirror.id = u.id
        } catch { mirror.error = error.localizedDescription }
        mirror.isLoading = false
    }
}

// MARK: - Favicon URLs (same as Android version)
private let verificationFavicons: [String: String] = [
    "gosuslugi": "https://www.gosuslugi.ru/favicon.ico",
    "alfa":      "https://alfabank.ru/favicon.ico",
    "tinkoff":   "https://cdn.tbank.ru/params/common_front/resourses/icons/favicon-32x32.png",
    "sber":      "https://www.sberbank.ru/common_static/favicon.ico",
    "vtb":       "https://www.vtb.ru/favicon.ico"
]

private let verificationNames: [String: String] = [
    "gosuslugi": "Госуслуги",
    "alfa":      "Альфа-Банк",
    "tinkoff":   "Т-Банк",
    "sber":      "СберБанк",
    "vtb":       "ВТБ"
]

// MARK: - Verification Row
struct VerificationRow: View {
    let user: VKUser
    let fakeVerif: Bool

    private var isVKVerified: Bool { fakeVerif || user.verified == 1 }
    private var verifications: [VKVerification] {
        (user.verificationInfo?.verifications ?? []).sorted { ($0.priority ?? 99) < ($1.priority ?? 99) }
    }
    private var hasAny: Bool { isVKVerified || !verifications.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hasAny ? Color(r:0x1D,g:0xA1,b:0xF2).opacity(0.15) : Color.surfaceVar)
                        .frame(width: 28, height: 28)
                    Image(systemName: hasAny ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(.system(size: 14))
                        .foregroundStyle(hasAny ? Color(r:0x1D,g:0xA1,b:0xF2) : Color.onSurfaceMut)
                }
                Text("Верификация")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.onSurface)
                Spacer()
                if !hasAny {
                    Text("Отсутствует")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.onSurfaceMut)
                } else {
                    // Show badges inline
                    HStack(spacing: 5) {
                        // Blue VK badge
                        if isVKVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(r:0x1D,g:0xA1,b:0xF2))
                        }
                        // Service favicons
                        ForEach(verifications, id: \.type) { v in
                            ServiceFaviconView(type: v.type)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            // Service details if any third-party verifications
            if !verifications.isEmpty {
                Divider().background(Color.divider).padding(.leading, 56)
                VStack(spacing: 0) {
                    ForEach(Array(verifications.enumerated()), id: \.element.type) { idx, v in
                        HStack(spacing: 12) {
                            ServiceFaviconView(type: v.type)
                                .frame(width: 28)
                            Text(verificationNames[v.type] ?? v.name ?? v.type)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.onSurface)
                            Spacer()
                            Text("Подтверждено")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(r:0x52,g:0xC4,b:0x1A))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(r:0x52,g:0xC4,b:0x1A).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        if idx < verifications.count - 1 {
                            Divider().background(Color.divider).padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Service favicon view
struct ServiceFaviconView: View {
    let type: String
    @State private var image: UIImage? = nil
    @State private var failed = false

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if failed {
                // Fallback: colored letter badge
                let (bg, fg, letter) = fallbackStyle(type)
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(bg).frame(width: 20, height: 20)
                    Text(letter).font(.system(size: 10, weight: .black)).foregroundStyle(fg)
                }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.surfaceVar)
                    .frame(width: 20, height: 20)
            }
        }
        .task(id: type) {
            guard let urlStr = verificationFavicons[type],
                  let url = URL(string: urlStr) else { failed = true; return }
            if let cached = ImageCache.shared.get(urlStr) { image = cached; return }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = UIImage(data: data) else { failed = true; return }
            ImageCache.shared.set(urlStr, image: img)
            image = img
        }
    }

    private func fallbackStyle(_ t: String) -> (Color, Color, String) {
        switch t {
        case "gosuslugi": return (Color(r:0x00,g:0x61,b:0xAA), .white, "ГУ")
        case "alfa":      return (Color(r:0xEF,g:0x31,b:0x24), .white,  "А")
        case "tinkoff":   return (Color(r:0xFF,g:0xDD,b:0x2D), Color(r:0x33,g:0x33,b:0x33), "Т")
        case "sber":      return (Color(r:0x21,g:0xA0,b:0x38), .white,  "С")
        case "vtb":       return (Color(r:0x00,g:0x2A,b:0x6E), .white,  "В")
        default:          return (Color(r:0x75,g:0x75,b:0x75), .white,  "?")
        }
    }
}

// MARK: - Profile History Section
private struct ProfileHistorySection: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var users: [VKUser] = []
    @State private var isLoading = false

    var body: some View {
        if !store.profileHistory.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(Color.cyberBlue)
                    Text("История просмотров").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.onSurface)
                    Spacer()
                    Button {
                        store.profileHistory = []
                        users = []
                    } label: {
                        Text("Очистить").font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                    }
                }
                .padding(.horizontal, 4)

                if isLoading {
                    ProgressView().tint(.cyberBlue).frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(users.enumerated()), id: \.element.id) { idx, u in
                            NavigationLink(destination: FriendProfileView(user: u)) {
                                HStack(spacing: 10) {
                                    AvatarView(url: u.photo100, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(u.fullName).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.onSurface).lineLimit(1)
                                        Text("vk.com/id\(u.id)").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                                    }
                                    Spacer()
                                    if u.verified == 1 {
                                        Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(Color.cyberBlue)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                            }
                            if idx < users.count - 1 {
                                Divider().background(Color.divider).padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.divider, lineWidth: 0.5))
                }
            }
            .task(id: store.profileHistory.first) { await loadUsers() }
        }
    }

    private func loadUsers() async {
        guard !store.profileHistory.isEmpty else { return }
        isLoading = true
        let ids = store.profileHistory.prefix(20).map(String.init).joined(separator: ",")
        if let fetched = try? await VKAPIClient.shared.getUsers(ids: ids) {
            // preserve history order
            let map = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            users = store.profileHistory.prefix(20).compactMap { map[$0] }
        }
        isLoading = false
    }
}
