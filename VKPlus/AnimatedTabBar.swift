import SwiftUI

// MARK: - Tab order persistence
private let tabOrderKey = "tab_order"

func loadTabOrder() -> [Int] {
    let saved = UserDefaults.standard.array(forKey: tabOrderKey) as? [Int] ?? []
    if saved.count == 6 { return saved }
    return [0, 1, 2, 3, 4, 5]
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
                .minimumScaleFactor(0.60)
                .fixedSize(horizontal: false, vertical: true)
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
            let arm: CGFloat = 5; let thick: CGFloat = 1.8; let inset: CGFloat = 2
            let color = Color(red: 0.38, green: 0.72, blue: 1.0)
            let alpha: Double = glowing ? 1.0 : 0.55
            if glowing {
                ctx.fill(Path(roundedRect: CGRect(x: inset+arm, y: 0, width: w-(inset+arm)*2, height: h), cornerRadius: 3),
                         with: .color(Color(red:0.18,green:0.60,blue:1.0).opacity(0.10)))
            }
            func hline(_ x1: CGFloat,_ y: CGFloat,_ x2: CGFloat) {
                var p = Path(); p.move(to: CGPoint(x:x1,y:y)); p.addLine(to: CGPoint(x:x2,y:y))
                ctx.stroke(p, with: .color(color.opacity(alpha)), lineWidth: thick)
            }
            func vline(_ x: CGFloat,_ y1: CGFloat,_ y2: CGFloat) {
                var p = Path(); p.move(to: CGPoint(x:x,y:y1)); p.addLine(to: CGPoint(x:x,y:y2))
                ctx.stroke(p, with: .color(color.opacity(alpha)), lineWidth: thick)
            }
            let lx = inset+thick/2; let rx = w-inset-thick/2
            vline(lx, inset, h-inset); hline(inset, inset+thick/2, inset+arm); hline(inset, h-inset-thick/2, inset+arm)
            vline(rx, inset, h-inset); hline(w-inset, inset+thick/2, w-inset-arm); hline(w-inset, h-inset-thick/2, w-inset-arm)
            if glowing {
                let gc = Color(red:0.30,green:0.75,blue:1.0)
                for a in [0.12, 0.08] {
                    var p1 = Path(); p1.move(to:CGPoint(x:lx,y:inset)); p1.addLine(to:CGPoint(x:lx,y:h-inset))
                    ctx.stroke(p1, with:.color(gc.opacity(a)), lineWidth: thick+4)
                    var p2 = Path(); p2.move(to:CGPoint(x:rx,y:inset)); p2.addLine(to:CGPoint(x:rx,y:h-inset))
                    ctx.stroke(p2, with:.color(gc.opacity(a)), lineWidth: thick+4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: glowing)
    }
}

// MARK: - Custom Tab Bar with drag-to-reorder
struct AnimatedTabBar: View {
    @Binding var selected: Int
    @ObservedObject var toastMgr = ToastManager.shared
    @ObservedObject private var store = SettingsStore.shared

    // Tab definitions (fixed, indexed 0-5)
    let tabDefs: [(icon: String, label: String)] = [
        ("house.fill",                      "Лента"),
        ("bubble.left.and.bubble.right.fill","Сообщения"),
        ("person.2.fill",                   "Друзья"),
        ("person.fill",                     "Профиль"),
        ("gearshape.fill",                  "Настройки"),
        ("building.columns.fill",           "Сообщества"),
    ]

    // Persisted order: each element is a tab index 0-5
    @State private var tabOrder: [Int] = loadTabOrder()

    // Drag state
    @State private var draggingIdx: Int? = nil      // position in tabOrder being dragged
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let tabW = geo.size.width / CGFloat(tabOrder.count)
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    ForEach(Array(tabOrder.enumerated()), id: \.offset) { pos, tabIdx in
                        let isSelected = selected == tabIdx
                        let isDraggedItem = draggingIdx == pos

                        AnimatedTabItem(
                            icon:       tabDefs[tabIdx].icon,
                            label:      tabDefs[tabIdx].label,
                            isSelected: isSelected,
                            badgeCount: 0,
                            tabIndex:   tabIdx
                        )
                        .frame(width: tabW)
                        .opacity(isDraggedItem ? 0.0 : 1.0)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isDragging { selected = tabIdx }
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.4)
                                .onEnded { _ in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring(response: 0.3)) {
                                        draggingIdx = pos
                                        isDragging = true
                                        dragOffset = 0
                                    }
                                }
                        )
                    }
                }

                // Floating dragged item
                if let dragPos = draggingIdx {
                    let tabIdx = tabOrder[dragPos]
                    AnimatedTabItem(
                        icon:       tabDefs[tabIdx].icon,
                        label:      tabDefs[tabIdx].label,
                        isSelected: selected == tabIdx,
                        badgeCount: 0,
                        tabIndex:   tabIdx
                    )
                    .frame(width: tabW)
                    .scaleEffect(1.12)
                    .shadow(color: Color.cyberBlue.opacity(0.4), radius: 12)
                    .offset(x: tabW * CGFloat(dragPos) - geo.size.width/2 + tabW/2 + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                dragOffset = val.translation.width
                                // Calculate target position
                                let currentX = tabW * CGFloat(dragPos) + dragOffset
                                let targetPos = max(0, min(tabOrder.count - 1, Int((currentX + tabW/2) / tabW)))
                                if targetPos != dragPos {
                                    withAnimation(.spring(response: 0.25)) {
                                        var newOrder = tabOrder
                                        newOrder.remove(at: dragPos)
                                        newOrder.insert(tabIdx, at: targetPos)
                                        tabOrder = newOrder
                                        draggingIdx = targetPos
                                        dragOffset = currentX - tabW * CGFloat(targetPos)
                                    }
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                    draggingIdx = nil
                                    isDragging = false
                                }
                                saveTabOrder(tabOrder)
                                // Update selected to match new position
                            }
                    )
                }
            }
        }
        .frame(height: 60)
        .padding(.top, 6)
        .padding(.bottom, 26)
        .background(tabBarBackground)
    }

    @ViewBuilder private var tabBarBackground: some View {
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
                tabView(for: 0).opacity(selectedTab == 0 ? 1 : 0).allowsHitTesting(selectedTab == 0)
                tabView(for: 1).opacity(selectedTab == 1 ? 1 : 0).allowsHitTesting(selectedTab == 1)
                tabView(for: 2).opacity(selectedTab == 2 ? 1 : 0).allowsHitTesting(selectedTab == 2)
                tabView(for: 3).opacity(selectedTab == 3 ? 1 : 0).allowsHitTesting(selectedTab == 3)
                tabView(for: 4).opacity(selectedTab == 4 ? 1 : 0).allowsHitTesting(selectedTab == 4)
                tabView(for: 5).opacity(selectedTab == 5 ? 1 : 0).allowsHitTesting(selectedTab == 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 92)
            .gesture(
                DragGesture(minimumDistance: 40, coordinateSpace: .local)
                    .onEnded { val in
                        guard abs(val.translation.width) > abs(val.translation.height) * 1.5 else { return }
                        let order = loadTabOrder()
                        let curPos = order.firstIndex(of: selectedTab) ?? selectedTab
                        withAnimation(.easeInOut(duration: 0.22)) {
                            if val.translation.width < 0 {
                                let nextPos = min(curPos + 1, 5)
                                selectedTab = order[nextPos]
                            } else {
                                let prevPos = max(curPos - 1, 0)
                                selectedTab = order[prevPos]
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
