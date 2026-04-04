import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        TabView {
            NavigationStack { FeedView() }
                .tabItem { Label("Лента",      systemImage: "house.fill") }
            NavigationStack { MessagesView() }
                .tabItem { Label("Сообщения",  systemImage: "bubble.left.and.bubble.right.fill") }
            NavigationStack { FriendsView() }
                .tabItem { Label("Друзья",     systemImage: "person.2.fill") }
            NavigationStack { ProfileView() }
                .tabItem { Label("Профиль",    systemImage: "person.fill") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Ещё",        systemImage: "ellipsis.circle.fill") }
            NavigationStack { AboutView() }
                .tabItem { Label("About Dev",  systemImage: "person.crop.circle.badge.checkmark") }
        }
        .tint(.cyberBlue)
        .toolbarBackground(Color.surface, for: .tabBar)
        .toolbarBackground(.visible,      for: .tabBar)
        .toolbarColorScheme(.dark,         for: .tabBar)
    }
}
