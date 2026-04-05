import SwiftUI

// MARK: - Animated Tab Item
struct AnimatedTabItem: View {
    let icon:       String
    let label:      String
    let isSelected: Bool
    let badgeCount: Int
    var tabIndex:   Int = 0

    @State private var bouncing     = false
    @State private var glowing      = false
    @State private var prevSelected = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                // [ ] bracket selection indicator
                if isSelected {
                    BracketHighlight(glowing: glowing)
                        .frame(width: 44, height: 30)
                }

                // Custom animated icon
                AnimatedTabIcon(tab: tabIndex, isSelected: isSelected, size: 22)
                    .frame(width: 44, height: 30)
                    .scaleEffect(bouncing ? 1.14 : 1.0)
                    .animation(.spring(response: 0.26, dampingFraction: 0.44), value: bouncing)

                // Badge
                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Color.errorRed)
                        .clipShape(Capsule())
                        .offset(x: 14, y: -4)
                }
            }

            Text(label)
                .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.cyberBlue : Color.onSurfaceMut.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .onChange(of: isSelected) { _, newVal in
            if newVal && !prevSelected {
                bouncing = true; glowing = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { bouncing = false }
            } else if !newVal {
                withAnimation(.easeOut(duration: 0.25)) { glowing = false }
            }
            prevSelected = newVal
        }
        .onAppear { prevSelected = isSelected; if isSelected { glowing = true } }
    }
}

// MARK: - Bracket [ ] highlight with glow
private struct BracketHighlight: View {
    let glowing: Bool

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let arm: CGFloat = 6      // bracket arm length (horizontal)
            let thick: CGFloat = 1.8  // line thickness
            let inset: CGFloat = 2    // padding from edges
            let glow = glowing

            // Glow fill background
            if glow {
                let bgRect = CGRect(x: inset+arm, y: 0, width: w - (inset+arm)*2, height: h)
                ctx.fill(
                    Path(roundedRect: bgRect, cornerRadius: 3),
                    with: .color(Color(red: 0.18, green: 0.60, blue: 1.0).opacity(0.10))
                )
            }

            let color = Color(red: 0.38, green: 0.72, blue: 1.0)
            let alpha: Double = glow ? 1.0 : 0.55

            // LEFT bracket [
            // vertical bar
            var lb = Path()
            lb.move(to: CGPoint(x: inset + thick/2, y: inset))
            lb.addLine(to: CGPoint(x: inset + thick/2, y: h - inset))
            ctx.stroke(lb, with: .color(color.opacity(alpha)), lineWidth: thick)
            // top arm
            var lt = Path()
            lt.move(to: CGPoint(x: inset, y: inset + thick/2))
            lt.addLine(to: CGPoint(x: inset + arm, y: inset + thick/2))
            ctx.stroke(lt, with: .color(color.opacity(alpha)), lineWidth: thick)
            // bottom arm
            var lb2 = Path()
            lb2.move(to: CGPoint(x: inset, y: h - inset - thick/2))
            lb2.addLine(to: CGPoint(x: inset + arm, y: h - inset - thick/2))
            ctx.stroke(lb2, with: .color(color.opacity(alpha)), lineWidth: thick)

            // RIGHT bracket ]
            let rx = w - inset - thick/2
            // vertical bar
            var rb = Path()
            rb.move(to: CGPoint(x: rx, y: inset))
            rb.addLine(to: CGPoint(x: rx, y: h - inset))
            ctx.stroke(rb, with: .color(color.opacity(alpha)), lineWidth: thick)
            // top arm
            var rt = Path()
            rt.move(to: CGPoint(x: w - inset, y: inset + thick/2))
            rt.addLine(to: CGPoint(x: w - inset - arm, y: inset + thick/2))
            ctx.stroke(rt, with: .color(color.opacity(alpha)), lineWidth: thick)
            // bottom arm
            var rb2 = Path()
            rb2.move(to: CGPoint(x: w - inset, y: h - inset - thick/2))
            rb2.addLine(to: CGPoint(x: w - inset - arm, y: h - inset - thick/2))
            ctx.stroke(rb2, with: .color(color.opacity(alpha)), lineWidth: thick)

            // Glow effect — same paths with blur via opacity layers
            if glow {
                for blurAlpha in [0.12, 0.08] {
                    let gc = Color(red: 0.30, green: 0.75, blue: 1.0)
                    var glb = Path()
                    glb.move(to: CGPoint(x: inset + thick/2, y: inset))
                    glb.addLine(to: CGPoint(x: inset + thick/2, y: h - inset))
                    ctx.stroke(glb, with: .color(gc.opacity(blurAlpha)), lineWidth: thick + 4)
                    var grb = Path()
                    grb.move(to: CGPoint(x: rx, y: inset))
                    grb.addLine(to: CGPoint(x: rx, y: h - inset))
                    ctx.stroke(grb, with: .color(gc.opacity(blurAlpha)), lineWidth: thick + 4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: glowing)
    }
}

// MARK: - Custom Tab Bar
struct AnimatedTabBar: View {
    @Binding var selected: Int
    @ObservedObject var toastMgr = ToastManager.shared
    @ObservedObject private var store = SettingsStore.shared

    private let tabs: [(icon: String, selectedIcon: String, label: String)] = [
        ("house",                    "house.fill",                      "Лента"),
        ("bubble.left.and.bubble.right", "bubble.left.and.bubble.right.fill", "Сообщения"),
        ("person.2",                 "person.2.fill",                   "Друзья"),
        ("person",                   "person.fill",                     "Профиль"),
        ("gearshape",                 "gearshape.fill",                  "Настройки"),
        ("building.columns", "building.columns.fill", "Сообщества"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                AnimatedTabItem(
                    icon: tabs[i].icon,
                    label: tabs[i].label,
                    isSelected: selected == i,
                    badgeCount: 0,
                    tabIndex: i
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { if selected != i { selected = i } }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let tabW = UIScreen.main.bounds.width / CGFloat(tabs.count)
                            let newIdx = Int((v.location.x + tabW * CGFloat(i)) / tabW)
                            let clamped = max(0, min(tabs.count-1, newIdx))
                            if clamped != selected { selected = clamped }
                        }
                )
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 26)
        .background(
            ZStack {
                if store.liquidGlass {
                    Rectangle().fill(.ultraThinMaterial)
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.white.opacity(0.03), Color.clear],
                                startPoint: .top, endPoint: .bottom))
                            .frame(height: 12)
                        Spacer()
                    }
                    Color.cyberBlue.opacity(0.03)
                } else {
                    Color.surface
                }
                // Top border line with blue gradient
                VStack {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(store.liquidGlass ? 0.20 : 0),
                                     Color.cyberBlue.opacity(0.30), Color.clear],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(height: 0.5)
                    Spacer()
                }
            }
        )
    }
}

// MARK: - MainTabView using AnimatedTabBar
struct AnimatedMainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab = 0
    @ObservedObject private var store = SettingsStore.shared

    private let tabCount = 6

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                tabView(for: 0).opacity(selectedTab == 0 ? 1 : 0).allowsHitTesting(selectedTab == 0)
                tabView(for: 1).opacity(selectedTab == 1 ? 1 : 0).allowsHitTesting(selectedTab == 1)
                tabView(for: 2).opacity(selectedTab == 2 ? 1 : 0).allowsHitTesting(selectedTab == 2)
                tabView(for: 3).opacity(selectedTab == 3 ? 1 : 0).allowsHitTesting(selectedTab == 3)
                tabView(for: 4).opacity(selectedTab == 4 ? 1 : 0).allowsHitTesting(selectedTab == 4)
                tabView(for: 5).opacity(selectedTab == 5 ? 1 : 0).allowsHitTesting(selectedTab == 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 80)
            .gesture(
                DragGesture(minimumDistance: 40, coordinateSpace: .local)
                    .onEnded { val in
                        guard abs(val.translation.width) > abs(val.translation.height) * 1.5 else { return }
                        withAnimation(.easeInOut(duration: 0.22)) {
                            if val.translation.width < 0 {
                                selectedTab = min(selectedTab + 1, tabCount - 1)
                            } else {
                                selectedTab = max(selectedTab - 1, 0)
                            }
                        }
                    }
            )

            AnimatedTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .toastOverlay()
    }

    @ViewBuilder
    private func tabView(for index: Int) -> some View {
        switch index {
        case 0: NavigationStack { FeedView() }
        case 1: NavigationStack { MessagesView() }
        case 2: NavigationStack { FriendsView() }
        case 3: NavigationStack { ProfileView() }
        case 4: NavigationStack { SettingsView() }
        case 5: NavigationStack { CommunitiesView() }
        default: NavigationStack { FeedView() }
        }
    }
}
