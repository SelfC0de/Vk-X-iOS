import SwiftUI

// MARK: - Animated Tab Item
struct AnimatedTabItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let badgeCount: Int

    @State private var bouncing   = false
    @State private var glowing    = false
    @State private var prevSelected = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                // Glow ring behind icon when selected
                if isSelected {
                    Circle()
                        .fill(Color.cyberBlue.opacity(glowing ? 0.18 : 0.06))
                        .frame(width: 38, height: 38)
                        .scaleEffect(glowing ? 1.15 : 0.9)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glowing)
                }

                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.cyberBlue : Color.onSurfaceMut)
                    .scaleEffect(bouncing ? 1.28 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.45), value: bouncing)

                // Badge
                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.errorRed)
                        .clipShape(Capsule())
                        .offset(x: 10, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 38, height: 38)

            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.cyberBlue : Color.onSurfaceMut)
        }
        .onChange(of: isSelected) { _, newVal in
            if newVal && !prevSelected {
                bouncing = true
                glowing  = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { bouncing = false }
            } else if !newVal {
                glowing = false
            }
            prevSelected = newVal
        }
        .onAppear {
            prevSelected = isSelected
            if isSelected { glowing = true }
        }
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
        ("person.crop.circle.badge.checkmark", "person.crop.circle.badge.checkmark", "About Dev"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    if selected != i { selected = i }
                } label: {
                    AnimatedTabItem(
                        icon: selected == i ? tabs[i].selectedIcon : tabs[i].icon,
                        label: tabs[i].label,
                        isSelected: selected == i,
                        badgeCount: 0
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(
            ZStack {
                if store.liquidGlass {
                    // Liquid Glass: blur + translucent overlay
                    if #available(iOS 26.0, *) {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                LinearGradient(
                                    colors: [Color.cyberBlue.opacity(0.08), Color.clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    } else {
                        // iOS 17-25 fallback
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(Color.cyberBlue.opacity(0.04))
                    }
                } else {
                    Color.surface
                }
                // Top separator
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyberBlue.opacity(store.liquidGlass ? 0.5 : 0.3), Color.divider.opacity(0.3)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case 0: NavigationStack { FeedView() }
                case 1: NavigationStack { MessagesView() }
                case 2: NavigationStack { FriendsView() }
                case 3: NavigationStack { ProfileView() }
                case 4: NavigationStack { SettingsView() }
                case 5: NavigationStack { AboutView() }
                default: NavigationStack { FeedView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 82) // room for tab bar

            AnimatedTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .toastOverlay()
    }
}
