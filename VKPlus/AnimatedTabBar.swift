import SwiftUI

// MARK: - Animated Tab Item
struct AnimatedTabItem: View {
    let icon: String     // kept for compat, unused
    let label: String
    let isSelected: Bool
    let badgeCount: Int
    var tabIndex: Int = 0

    @State private var bouncing     = false
    @State private var glowing      = false
    @State private var prevSelected = false

    var body: some View {
        VStack(spacing: 1) {
            ZStack(alignment: .topTrailing) {
                // Glow capsule
                if isSelected {
                    Capsule()
                        .fill(Color.cyberBlue.opacity(glowing ? 0.18 : 0.08))
                        .frame(width: 40, height: 26)
                        .scaleEffect(glowing ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowing)
                }

                // Custom animated icon
                AnimatedTabIcon(tab: tabIndex, isSelected: isSelected, size: 24)
                    .scaleEffect(bouncing ? 1.15 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.42), value: bouncing)

                // Badge
                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Color.errorRed)
                        .clipShape(Capsule())
                        .offset(x: 10, y: -3)
                }
            }
            .frame(width: 40, height: 26)

            Text(label)
                .font(.system(size: 9.0, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.cyberBlue : Color.onSurfaceMut)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .onChange(of: isSelected) { _, newVal in
            if newVal && !prevSelected {
                bouncing = true; glowing = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { bouncing = false }
            } else if !newVal { glowing = false }
            prevSelected = newVal
        }
        .onAppear { prevSelected = isSelected; if isSelected { glowing = true } }
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
        ("ellipsis.circle",          "ellipsis.circle.fill",            "Ещё"),
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
                // Drag gesture: slide finger to switch tabs
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            // Find which tab the finger is currently over
                            let tabW = UIScreen.main.bounds.width / CGFloat(tabs.count)
                            let newIdx = Int((v.location.x + tabW * CGFloat(i)) / tabW)
                            let clamped = max(0, min(tabs.count-1, newIdx))
                            if clamped != selected { selected = clamped }
                        }
                )
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 24)
        .background(
            ZStack {
                if store.liquidGlass {
                    // iOS 26-style Liquid Glass: layered translucency
                    Rectangle().fill(.ultraThinMaterial)
                    // Specular highlight — top edge shimmer
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.04), Color.clear],
                                startPoint: .top, endPoint: .bottom))
                            .frame(height: 14)
                        Spacer()
                    }
                    // Tint
                    Color.cyberBlue.opacity(0.04)
                } else {
                    Color.surface
                }
                // Top separator
                VStack {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(store.liquidGlass ? 0.25 : 0),
                                     Color.cyberBlue.opacity(0.25), Color.clear],
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
            // Tab content with swipe gesture
            ZStack {
                tabView(for: 0).opacity(selectedTab == 0 ? 1 : 0).allowsHitTesting(selectedTab == 0)
                tabView(for: 1).opacity(selectedTab == 1 ? 1 : 0).allowsHitTesting(selectedTab == 1)
                tabView(for: 2).opacity(selectedTab == 2 ? 1 : 0).allowsHitTesting(selectedTab == 2)
                tabView(for: 3).opacity(selectedTab == 3 ? 1 : 0).allowsHitTesting(selectedTab == 3)
                tabView(for: 4).opacity(selectedTab == 4 ? 1 : 0).allowsHitTesting(selectedTab == 4)
                tabView(for: 5).opacity(selectedTab == 5 ? 1 : 0).allowsHitTesting(selectedTab == 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, store.liquidGlass ? 76 : 78)
            .gesture(
                DragGesture(minimumDistance: 40, coordinateSpace: .local)
                    .onEnded { val in
                        // Only horizontal swipes (more horizontal than vertical)
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
