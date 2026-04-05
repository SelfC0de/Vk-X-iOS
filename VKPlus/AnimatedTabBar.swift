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
    @ObservedObject var toastMgr = ToastManager.shared
    @ObservedObject private var store = SettingsStore.shared

    let tabDefs: [(icon: String, label: String)] = [
        ("house.fill",                        "Лента"),
        ("bubble.left.and.bubble.right.fill", "Сообщения"),
        ("person.2.fill",                     "Друзья"),
        ("person.fill",                       "Профиль"),
        ("gearshape.fill",                    "Настройки"),
        ("building.columns.fill",             "Сообщества"),
    ]

    @State private var tabOrder:    [Int]    = loadTabOrder()
    @State private var dragPos:     Int?     = nil   // which position is being dragged
    @State private var dragX:       CGFloat  = 0     // current finger X in bar coords
    @State private var tabBarWidth: CGFloat  = 0

    private var tabW: CGFloat { tabBarWidth / 6 }

    var body: some View {
        ZStack {
            // ── Static items ──────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { pos in
                    let tabIdx = tabOrder[pos]
                    let isGhost = dragPos == pos   // hide while floating

                    AnimatedTabItem(
                        icon:       tabDefs[tabIdx].icon,
                        label:      tabDefs[tabIdx].label,
                        isSelected: selected == tabIdx && dragPos == nil,
                        badgeCount: 0,
                        tabIndex:   tabIdx
                    )
                    .frame(maxWidth: .infinity)
                    .opacity(isGhost ? 0 : 1)
                    // Normal tap — only when NOT dragging
                    .onTapGesture {
                        guard dragPos == nil else { return }
                        selected = tabIdx
                    }
                    // Long press starts drag
                    .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 10) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dragPos = pos
                        dragX   = tabW * CGFloat(pos) + tabW / 2
                    }
                }
            }

            // ── Floating dragged item ─────────────────────────────────
            if let dp = dragPos {
                let tabIdx = tabOrder[dp]
                AnimatedTabItem(
                    icon:       tabDefs[tabIdx].icon,
                    label:      tabDefs[tabIdx].label,
                    isSelected: selected == tabIdx,
                    badgeCount: 0,
                    tabIndex:   tabIdx
                )
                .frame(width: tabW)
                .scaleEffect(1.15)
                .shadow(color: Color.cyberBlue.opacity(0.5), radius: 14)
                .position(x: dragX, y: 30)  // fixed Y center in bar
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("tabbar"))
                        .onChanged { val in
                            dragX = max(tabW/2, min(tabBarWidth - tabW/2, val.location.x))
                            // Swap logic
                            let targetPos = min(5, max(0, Int(dragX / tabW)))
                            if targetPos != dp {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    var order = tabOrder
                                    order.remove(at: dp)
                                    order.insert(tabIdx, at: targetPos)
                                    tabOrder = order
                                    dragPos  = targetPos
                                }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3)) {
                                dragPos = nil
                                dragX   = 0
                            }
                            saveTabOrder(tabOrder)
                        }
                )
                .zIndex(10)
            }
        }
        .coordinateSpace(name: "tabbar")
        // Measure bar width once
        .background(
            GeometryReader { g in
                Color.clear.onAppear { tabBarWidth = g.size.width }
                    .onChange(of: g.size.width) { _, w in tabBarWidth = w }
            }
        )
        .frame(height: 60)
        .padding(.top, 6)
        .padding(.bottom, 26)
        .background(barBackground)
    }

    @ViewBuilder private var barBackground: some View {
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
