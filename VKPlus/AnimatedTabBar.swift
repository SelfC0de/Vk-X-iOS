// MARK: - Unread Count Manager
final class UnreadCountManager: ObservableObject {
    static let shared = UnreadCountManager()
    @Published var count: Int = 0
    private var task: Task<Void, Never>? = nil
    private init() {}

    func start() {
        guard task == nil else { return }
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                if let n = try? await VKAPIClient.shared.getUnreadCount() {
                    self?.count = n
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }
    func stop() { task?.cancel(); task = nil }
}

import SwiftUI

// MARK: - Tab order persistence
private let tabOrderKey = "tab_order"

func loadTabOrder() -> [Int] {
    let saved = UserDefaults.standard.array(forKey: tabOrderKey) as? [Int] ?? []
    return saved.count == 6 ? saved : [0,1,2,3,4,5]
}

func saveTabOrder(_ order: [Int]) {
    UserDefaults.standard.set(order, forKey: tabOrderKey)
}

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
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                if isSelected {
                    BracketHighlight(glowing: glowing)
                        .frame(width: 40, height: 28)
                }
                AnimatedTabIcon(tab: tabIndex, isSelected: isSelected, size: 21)
                    .frame(width: 40, height: 28)
                    .scaleEffect(bouncing ? 1.14 : 1.0)
                    .animation(.spring(response: 0.26, dampingFraction: 0.44), value: bouncing)
                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Color.errorRed)
                        .clipShape(Capsule())
                        .offset(x: 13, y: -4)
                }
            }
            Text(label)
                .font(.system(size: 8.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.cyberBlue : Color.onSurfaceMut.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
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

// MARK: - Bracket highlight
private struct BracketHighlight: View {
    let glowing: Bool
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let arm: CGFloat = 5, thick: CGFloat = 1.8, inset: CGFloat = 2
            let color = Color(red:0.38,green:0.72,blue:1.0)
            let alpha: Double = glowing ? 1.0 : 0.55
            if glowing {
                ctx.fill(Path(roundedRect: CGRect(x:inset+arm,y:0,width:w-(inset+arm)*2,height:h),cornerRadius:3),
                         with:.color(Color(red:0.18,green:0.60,blue:1.0).opacity(0.10)))
            }
            func hline(_ x1:CGFloat,_ y:CGFloat,_ x2:CGFloat){var p=Path();p.move(to:CGPoint(x:x1,y:y));p.addLine(to:CGPoint(x:x2,y:y));ctx.stroke(p,with:.color(color.opacity(alpha)),lineWidth:thick)}
            func vline(_ x:CGFloat,_ y1:CGFloat,_ y2:CGFloat){var p=Path();p.move(to:CGPoint(x:x,y:y1));p.addLine(to:CGPoint(x:x,y:y2));ctx.stroke(p,with:.color(color.opacity(alpha)),lineWidth:thick)}
            let lx=inset+thick/2,rx=w-inset-thick/2
            vline(lx,inset,h-inset);hline(inset,inset+thick/2,inset+arm);hline(inset,h-inset-thick/2,inset+arm)
            vline(rx,inset,h-inset);hline(w-inset,inset+thick/2,w-inset-arm);hline(w-inset,h-inset-thick/2,w-inset-arm)
            if glowing {
                let gc=Color(red:0.30,green:0.75,blue:1.0)
                for a in [0.12,0.08]{var p1=Path();p1.move(to:CGPoint(x:lx,y:inset));p1.addLine(to:CGPoint(x:lx,y:h-inset));ctx.stroke(p1,with:.color(gc.opacity(a)),lineWidth:thick+4);var p2=Path();p2.move(to:CGPoint(x:rx,y:inset));p2.addLine(to:CGPoint(x:rx,y:h-inset));ctx.stroke(p2,with:.color(gc.opacity(a)),lineWidth:thick+4)}
            }
        }
        .animation(.easeInOut(duration: 0.3), value: glowing)
    }
}

// MARK: - Tab Bar
struct AnimatedTabBar: View {
    @Binding var selected: Int
    @ObservedObject var toastMgr  = ToastManager.shared
    @ObservedObject private var store   = SettingsStore.shared
    @ObservedObject private var unreadMgr = UnreadCountManager.shared

    let tabDefs: [(icon: String, label: String)] = [
        ("house.fill",                        "Лента"),
        ("bubble.left.and.bubble.right.fill", "Сообщения"),
        ("person.2.fill",                     "Друзья"),
        ("person.fill",                       "Профиль"),
        ("gearshape.fill",                    "Настройки"),
        ("building.columns.fill",             "Сообщества"),
    ]

    @State private var tabOrder:   [Int]   = loadTabOrder()
    @State private var dragPos:    Int?    = nil
    @State private var dragX:      CGFloat = 0
    @State private var tabBarWidth: CGFloat = 0
    private var tabW: CGFloat { tabBarWidth / 6 }

    var body: some View {
        Group {
            switch store.tabBarStyle {
            case "liquid":  LiquidMorphingBar(selected: $selected, tabDefs: tabDefs)
            case "island":  FloatingIslandBar(selected: $selected, tabDefs: tabDefs)
            case "neon":    NeonGlowBar(selected: $selected, tabDefs: tabDefs)
            case "ticker":  TickerLabelBar(selected: $selected, tabDefs: tabDefs)
            case "gravity": GravityDropBar(selected: $selected, tabDefs: tabDefs)
            case "arc":     ArcMenuBar(selected: $selected, tabDefs: tabDefs)
            case "pill":    PillSelectorBar(selected: $selected, tabDefs: tabDefs)
            case "morph":   ShapeMorphBar(selected: $selected, tabDefs: tabDefs)
            case "rail":    SideRailBar(selected: $selected, tabDefs: tabDefs)
            case "mintop":  MinimalTopBar(selected: $selected, tabDefs: tabDefs)
            case "radial":  RadialDockBar(selected: $selected, tabDefs: tabDefs)
            default:        defaultBar
            }
        }
    }

    // ── Default (bracket) ────────────────────────────────────────────
    @ViewBuilder private var defaultBar: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { pos in
                    let tabIdx = tabOrder[pos]
                    let isGhost = dragPos == pos
                    AnimatedTabItem(icon: tabDefs[tabIdx].icon, label: tabDefs[tabIdx].label,
                                    isSelected: selected == tabIdx && dragPos == nil,
                                    badgeCount: tabIdx == 1 ? unreadMgr.count : 0, tabIndex: tabIdx)
                        .frame(maxWidth: .infinity)
                        .opacity(isGhost ? 0 : 1)
                        .onTapGesture { guard dragPos == nil else { return }; selected = tabIdx }
                        .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 10) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dragPos = pos; dragX = tabW * CGFloat(pos) + tabW / 2
                        }
                }
            }
            if let dp = dragPos {
                let tabIdx = tabOrder[dp]
                AnimatedTabItem(icon: tabDefs[tabIdx].icon, label: tabDefs[tabIdx].label,
                                isSelected: selected == tabIdx, badgeCount: 0, tabIndex: tabIdx)
                    .frame(width: tabW).scaleEffect(1.15)
                    .shadow(color: Color.cyberBlue.opacity(0.5), radius: 14)
                    .position(x: dragX, y: 30)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("tabbar"))
                        .onChanged { val in
                            dragX = max(tabW/2, min(tabBarWidth - tabW/2, val.location.x))
                            let targetPos = min(5, max(0, Int(dragX / tabW)))
                            if targetPos != dp {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    var order = tabOrder
                                    order.remove(at: dp); order.insert(tabIdx, at: targetPos)
                                    tabOrder = order; dragPos = targetPos
                                }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3)) { dragPos = nil; dragX = 0 }
                            saveTabOrder(tabOrder)
                        })
                    .zIndex(10)
            }
        }
        .coordinateSpace(name: "tabbar")
        .background(GeometryReader { g in
            Color.clear.onAppear { tabBarWidth = g.size.width }
                .onChange(of: g.size.width) { _, w in tabBarWidth = w }
        })
        .frame(height: 60).padding(.top, 6).padding(.bottom, 26)
        .background(barBg)
    }

    @ViewBuilder private var barBg: some View {
        ZStack {
            if store.liquidGlass {
                Rectangle().fill(.ultraThinMaterial)
                VStack(spacing:0){Rectangle().fill(LinearGradient(colors:[Color.white.opacity(0.16),Color.white.opacity(0.03),Color.clear],startPoint:.top,endPoint:.bottom)).frame(height:12);Spacer()}
                Color.cyberBlue.opacity(0.03)
            } else { Color.surface }
            VStack{Rectangle().fill(LinearGradient(colors:[Color.white.opacity(store.liquidGlass ? 0.20:0),Color.cyberBlue.opacity(0.30),Color.clear],startPoint:.leading,endPoint:.trailing)).frame(height:0.5);Spacer()}
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Liquid Morphing Bar
// ─────────────────────────────────────────────────────────────────────
struct LiquidMorphingBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]
    @State private var blobX: CGFloat = 0
    @State private var tabBarW: CGFloat = 0
    private var tabW: CGFloat { tabBarW / 6 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Blob
            if tabBarW > 0 {
                Ellipse()
                    .fill(Color.cyberBlue.opacity(0.18))
                    .frame(width: 52, height: 32)
                    .blur(radius: 6)
                    .offset(x: blobX - tabBarW / 2, y: 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.7), value: blobX)
            }
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    Button {
                        selected = i
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                            blobX = tabW * CGFloat(i) + tabW / 2
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tabDefs[i].icon)
                                .font(.system(size: 20))
                                .foregroundStyle(selected == i ? Color.cyberBlue : Color.onSurfaceMut.opacity(0.6))
                                .scaleEffect(selected == i ? 1.1 : 1.0)
                            Circle()
                                .fill(selected == i ? Color.cyberBlue : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.28, dampingFraction: 0.6), value: selected)
                }
            }
        }
        .frame(height: 60).padding(.top, 6).padding(.bottom, 26)
        .background(Color.surface)
        .background(GeometryReader { g in
            Color.clear.onAppear {
                tabBarW = g.size.width
                blobX = tabW * CGFloat(selected) + tabW / 2
            }
        })
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Floating Island Bar
// ─────────────────────────────────────────────────────────────────────
struct FloatingIslandBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]
    @State private var tilt: Double = 0

    var body: some View {
        ZStack {
            Color.surface
            VStack(spacing: 0) {
                Divider().background(Color.divider)
                Spacer()
            }
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    Button {
                        let prev = selected
                        selected = i
                        let dir = Double(i - prev)
                        withAnimation(.easeOut(duration: 0.15)) { tilt = dir * 3 }
                        withAnimation(.easeOut(duration: 0.25).delay(0.15)) { tilt = 0 }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tabDefs[i].icon)
                                .font(.system(size: selected == i ? 22 : 18))
                                .foregroundStyle(selected == i ? Color(r:0xA7,g:0x8B,b:0xFA) : Color.onSurfaceMut.opacity(0.55))
                                .offset(y: selected == i ? -6 : 0)
                            if selected == i {
                                Text(tabDefs[i].label)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color(r:0xA7,g:0x8B,b:0xFA))
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red:0.10,green:0.11,blue:0.18))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            )
            .padding(.horizontal, 16)
            .rotation3DEffect(.degrees(tilt), axis: (x:0,y:0,z:1))
            .animation(.easeInOut(duration: 0.25), value: tilt)
            .padding(.bottom, 20)
        }
        .frame(height: 86)
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Neon Glow Bar
// ─────────────────────────────────────────────────────────────────────
struct NeonGlowBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]
    @State private var lineX: CGFloat = 0
    @State private var tabBarW: CGFloat = 0
    @State private var pulse = false
    private var tabW: CGFloat { tabBarW / 6 }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.surface
            // Top border
            VStack(spacing:0){Rectangle().fill(LinearGradient(colors:[Color.white.opacity(0),Color(r:0x00,g:0xF5,b:0xFF).opacity(0.4),Color.white.opacity(0)],startPoint:.leading,endPoint:.trailing)).frame(height:0.5);Spacer()}

            // Sliding neon line
            if tabBarW > 0 {
                Capsule()
                    .fill(Color(r:0x00,g:0xF5,b:0xFF))
                    .frame(width: 28, height: 2)
                    .shadow(color: Color(r:0x00,g:0xF5,b:0xFF).opacity(0.8), radius: 6)
                    .offset(x: lineX - tabBarW / 2, y: -4)
                    .animation(.spring(response: 0.32, dampingFraction: 0.75), value: lineX)
            }

            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    Button {
                        selected = i
                        withAnimation { lineX = tabW * CGFloat(i) + tabW / 2 }
                        pulse = false
                        withAnimation(.easeOut(duration: 0.1)) { pulse = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pulse = false }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tabDefs[i].icon)
                                .font(.system(size: 20))
                                .foregroundStyle(selected == i ? Color(r:0x00,g:0xF5,b:0xFF) : Color.onSurfaceMut.opacity(0.5))
                                .shadow(color: selected == i ? Color(r:0x00,g:0xF5,b:0xFF).opacity(pulse && selected == i ? 0.9 : 0.4) : .clear, radius: 8)
                            Text(tabDefs[i].label)
                                .font(.system(size: 8))
                                .foregroundStyle(selected == i ? Color(r:0x00,g:0xF5,b:0xFF).opacity(0.8) : Color.onSurfaceMut.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeOut(duration: 0.2), value: selected)
                }
            }
            .padding(.bottom, 26)
            .background(GeometryReader { g in
                Color.clear.onAppear {
                    tabBarW = g.size.width
                    lineX = tabW * CGFloat(selected) + tabW / 2
                }
            })
        }
        .frame(height: 66)
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Ticker Label Bar
// ─────────────────────────────────────────────────────────────────────
struct TickerLabelBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]
    @State private var displayedLabel: String = ""
    @State private var tickerTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            Color.surface
            VStack(spacing: 0) {
                Divider().background(Color.divider)
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { i in
                        Button {
                            guard selected != i else { return }
                            selected = i
                            startTicker(for: tabDefs[i].label)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tabDefs[i].icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected == i ? Color(r:0xFF,g:0xB8,b:0x00) : Color.onSurfaceMut.opacity(0.55))
                                    .scaleEffect(selected == i ? 1.12 : 1.0)
                                if selected == i {
                                    Text(displayedLabel)
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color(r:0xFF,g:0xB8,b:0x00))
                                        .frame(height: 12)
                                        .transition(.opacity)
                                } else {
                                    Color.clear.frame(height: 12)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: selected)
                    }
                }
                .padding(.top, 6).padding(.bottom, 26)
            }
        }
        .frame(height: 66)
        .onAppear { displayedLabel = tabDefs[selected].label }
    }

    private func startTicker(for text: String) {
        tickerTask?.cancel()
        displayedLabel = ""
        tickerTask = Task {
            for char in text {
                if Task.isCancelled { break }
                await MainActor.run { displayedLabel += String(char) }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Gravity Drop Bar
// ─────────────────────────────────────────────────────────────────────
struct GravityDropBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]
    @State private var droppingIdx: Int? = nil
    @State private var dropPhase: CGFloat = 0 // 0=normal, 1=down, 2=bounce back

    var body: some View {
        ZStack {
            Color.surface
            VStack(spacing: 0) {
                Divider().background(Color.divider)
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { i in
                        Button {
                            selected = i
                            triggerDrop(for: i)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: tabDefs[i].icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected == i ? Color(r:0x34,g:0xD3,b:0x99) : Color.onSurfaceMut.opacity(0.55))
                                    .offset(y: droppingIdx == i ? dropPhase * 24 : 0)
                                    .animation(droppingIdx == i && dropPhase > 0
                                        ? .easeIn(duration: 0.12)
                                        : .spring(response: 0.4, dampingFraction: 0.45),
                                               value: dropPhase)
                                Text(tabDefs[i].label)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(selected == i ? Color(r:0x34,g:0xD3,b:0x99) : Color.onSurfaceMut.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6).padding(.bottom, 26)
            }
        }
        .frame(height: 66)
    }

    private func triggerDrop(for i: Int) {
        droppingIdx = i
        dropPhase = 0
        withAnimation(.easeIn(duration: 0.12)) { dropPhase = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            dropPhase = 0  // spring bounce back
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            if droppingIdx == i { droppingIdx = nil }
        }
    }
}

// MARK: - MainTabView
struct AnimatedMainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab = 0
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                tabView(for:0).opacity(selectedTab==0 ? 1:0).allowsHitTesting(selectedTab==0)
                tabView(for:1).opacity(selectedTab==1 ? 1:0).allowsHitTesting(selectedTab==1)
                tabView(for:2).opacity(selectedTab==2 ? 1:0).allowsHitTesting(selectedTab==2)
                tabView(for:3).opacity(selectedTab==3 ? 1:0).allowsHitTesting(selectedTab==3)
                tabView(for:4).opacity(selectedTab==4 ? 1:0).allowsHitTesting(selectedTab==4)
                tabView(for:5).opacity(selectedTab==5 ? 1:0).allowsHitTesting(selectedTab==5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 92)
            .gesture(
                DragGesture(minimumDistance: 40, coordinateSpace: .local)
                    .onEnded { val in
                        guard abs(val.translation.width) > abs(val.translation.height) * 1.5 else { return }
                        let order = loadTabOrder()
                        let cur   = order.firstIndex(of: selectedTab) ?? 0
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedTab = val.translation.width < 0
                                ? order[min(cur+1, 5)]
                                : order[max(cur-1, 0)]
                        }
                    }
            )
            AnimatedTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .toastOverlay()
        .onAppear { UnreadCountManager.shared.start() }
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

// ─────────────────────────────────────────────────────────────────────
// MARK: - Arc Menu Bar
// Полукруглый фон, иконки на дуге — центральная выше остальных
// ─────────────────────────────────────────────────────────────────────
struct ArcMenuBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]

    // Вертикальные смещения иконок по дуге: край→центр→край
    private let arcOffsets: [CGFloat] = [0, -6, -10, -6, 0, 4]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Фон-купол
            GeometryReader { geo in
                let w = geo.size.width
                Ellipse()
                    .fill(Color(red:0.08,green:0.08,blue:0.15))
                    .frame(width: w * 1.3, height: 70)
                    .offset(x: -w * 0.15, y: 10)
                Rectangle()
                    .fill(Color(red:0.08,green:0.08,blue:0.15))
                    .frame(width: w * 1.3, height: 30)
                    .offset(x: -w * 0.15, y: 40)
            }
            // Верхняя граница купола
            GeometryReader { geo in
                let w = geo.size.width
                Path { p in
                    p.addArc(center: CGPoint(x: w / 2, y: 80),
                             radius: w * 0.65,
                             startAngle: .degrees(180), endAngle: .degrees(0),
                             clockwise: false)
                }
                .stroke(Color(red:0.18,green:0.18,blue:0.32), lineWidth: 0.5)
            }

            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) { selected = i }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tabDefs[i].icon)
                                .font(.system(size: selected == i ? 22 : 18))
                                .foregroundStyle(selected == i
                                    ? Color(r:0x63,g:0x66,b:0xF1)
                                    : Color.onSurfaceMut.opacity(0.5))
                                .scaleEffect(selected == i ? 1.1 : 1.0)
                            Circle()
                                .fill(selected == i ? Color(r:0x63,g:0x66,b:0xF1) : Color.clear)
                                .frame(width: 3, height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .offset(y: arcOffsets[i])
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.32, dampingFraction: 0.65), value: selected)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 28)
        }
        .frame(height: 72)
        .background(Color.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.divider).frame(height: 0.5)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Pill Selector Bar
// Активная вкладка разворачивается в пилюлю с подписью
// ─────────────────────────────────────────────────────────────────────
struct PillSelectorBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]

    var body: some View {
        ZStack {
            Color.surface
            VStack(spacing: 0) {
                Divider().background(Color.divider)
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { i in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { selected = i }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: selected == i ? 5 : 0) {
                                Image(systemName: tabDefs[i].icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(selected == i
                                        ? Color(r:0xA5,g:0xB4,b:0xFC)
                                        : Color.onSurfaceMut.opacity(0.5))
                                if selected == i {
                                    Text(tabDefs[i].label)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color(r:0xA5,g:0xB4,b:0xFC))
                                        .lineLimit(1)
                                        .transition(.opacity)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, selected == i ? 12 : 8)
                            .background(
                                Capsule()
                                    .fill(selected == i
                                        ? Color(r:0x31,g:0x2E,b:0x81).opacity(0.8)
                                        : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selected)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8).padding(.bottom, 28)
            }
        }
        .frame(height: 66)
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Shape Morph Bar
// Иконка меняет форму: квадрат → круг при активации
// ─────────────────────────────────────────────────────────────────────
struct ShapeMorphBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]

    var body: some View {
        ZStack {
            Color.surface
            VStack(spacing: 0) {
                Divider().background(Color.divider)
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { i in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { selected = i }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: selected == i ? 14 : 6)
                                        .fill(selected == i
                                            ? Color(r:0x06,g:0xB6,b:0xD4).opacity(0.2)
                                            : Color(red:0.12,green:0.12,blue:0.18))
                                        .frame(width: 34, height: 34)
                                        .scaleEffect(selected == i ? 1.08 : 1.0)
                                    Image(systemName: tabDefs[i].icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(selected == i
                                            ? Color(r:0x06,g:0xB6,b:0xD4)
                                            : Color.onSurfaceMut.opacity(0.5))
                                }
                                Text(tabDefs[i].label)
                                    .font(.system(size: 8))
                                    .foregroundStyle(selected == i
                                        ? Color(r:0x06,g:0xB6,b:0xD4)
                                        : Color.onSurfaceMut.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: selected)
                    }
                }
                .padding(.top, 8).padding(.bottom, 26)
            }
        }
        .frame(height: 66)
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Side Rail Bar
// Вертикальная панель слева — нестандартный layout
// Используется как overlay поверх контента
// ─────────────────────────────────────────────────────────────────────
struct SideRailBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]

    var body: some View {
        // Горизонтальная заглушка внизу (занимает место таббара)
        // Реальный rail рисуется в MainTabView через overlay
        HStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = i }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tabDefs[i].icon)
                            .font(.system(size: 18))
                            .foregroundStyle(selected == i
                                ? Color(r:0xF4,g:0x72,b:0xB6)
                                : Color.onSurfaceMut.opacity(0.45))
                        Text(tabDefs[i].label)
                            .font(.system(size: 8))
                            .foregroundStyle(selected == i
                                ? Color(r:0xF4,g:0x72,b:0xB6)
                                : Color.onSurfaceMut.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selected == i
                            ? Color(r:0xF4,g:0x72,b:0xB6).opacity(0.1)
                            : Color.clear
                    )
                    .overlay(alignment: .top) {
                        if selected == i {
                            Rectangle()
                                .fill(Color(r:0xF4,g:0x72,b:0xB6))
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
            }
        }
        .padding(.bottom, 26)
        .background(Color(red:0.07,green:0.07,blue:0.12))
        .overlay(alignment: .top) {
            Rectangle().fill(Color(r:0xF4,g:0x72,b:0xB6).opacity(0.3)).frame(height: 0.5)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Minimal Top Bar
// Панель сверху — используется как navigationBar replacement
// Здесь рендерим как нижний таб для совместимости с MainTabView
// ─────────────────────────────────────────────────────────────────────
struct MinimalTopBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]
    @State private var lineOffset: CGFloat = 0
    @State private var barW: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { selected = i }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabDefs[i].icon)
                            .font(.system(size: 18))
                            .foregroundStyle(selected == i
                                ? Color(r:0xF5,g:0x9E,b:0x0B)
                                : Color.onSurfaceMut.opacity(0.45))
                        Text(tabDefs[i].label)
                            .font(.system(size: 8, weight: selected == i ? .semibold : .regular))
                            .foregroundStyle(selected == i
                                ? Color(r:0xF5,g:0x9E,b:0x0B)
                                : Color.onSurfaceMut.opacity(0.4))
                        Rectangle()
                            .fill(selected == i ? Color(r:0xF5,g:0x9E,b:0x0B) : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                            .scaleEffect(x: selected == i ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 26)
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
            }
        }
        .background(Color(red:0.06,green:0.06,blue:0.10))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.divider).frame(height: 0.5)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// MARK: - Radial Dock Bar
// Иконки расположены по полукругу — центральная выше всех
// ─────────────────────────────────────────────────────────────────────
struct RadialDockBar: View {
    @Binding var selected: Int
    let tabDefs: [(icon: String, label: String)]

    // Полукруг: углы 180°→0° слева направо (верхняя дуга)
    // Центр дуги cy = r + topPad, где r = barH - bottomPad - topPad
    // x_i = cx - r*cos(angle), y_i = cy - r*sin(angle)
    // sin(180..0) ≥ 0, поэтому y_i ≤ cy — иконки выше центра
    private func pos(index: Int, in size: CGSize) -> CGPoint {
        let topPad:    CGFloat = 14
        let bottomPad: CGFloat = 30
        let r  = size.height - bottomPad - topPad   // ~60pt
        let cx = size.width / 2
        let cy = r + topPad                          // центр дуги
        let angleDeg = 180.0 - Double(index) * 180.0 / 5.0  // 180,144,108,72,36,0
        let rad = angleDeg * Double.pi / 180.0
        let x = cx - r * CGFloat(cos(rad))
        let y = cy - r * CGFloat(sin(rad))
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red:0.07,green:0.07,blue:0.12)
                VStack(spacing:0){Rectangle().fill(Color.divider).frame(height:0.5);Spacer()}

                // Дуга-направляющая
                Path { p in
                    let topPad: CGFloat = 14
                    let bottomPad: CGFloat = 30
                    let r = geo.size.height - bottomPad - topPad
                    let cx = geo.size.width / 2
                    let cy = r + topPad
                    p.addArc(center: CGPoint(x: cx, y: cy),
                             radius: r,
                             startAngle: .degrees(0),
                             endAngle: .degrees(180),
                             clockwise: true)
                }
                .stroke(Color.white.opacity(0.07), lineWidth: 0.8)

                ForEach(0..<6, id: \.self) { i in
                    let p = pos(index: i, in: geo.size)
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { selected = i }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(selected == i
                                    ? Color(r:0x10,g:0xB9,b:0x81).opacity(0.22)
                                    : Color(red:0.12,green:0.12,blue:0.20))
                                .frame(width: selected == i ? 40 : 32,
                                       height: selected == i ? 40 : 32)
                            Image(systemName: tabDefs[i].icon)
                                .font(.system(size: selected == i ? 17 : 14))
                                .foregroundStyle(selected == i
                                    ? Color(r:0x10,g:0xB9,b:0x81)
                                    : Color.onSurfaceMut.opacity(0.5))
                        }
                        .scaleEffect(selected == i ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.32, dampingFraction: 0.6), value: selected)
                    .position(p)
                }
            }
        }
        .frame(height: 104)
    }
}
