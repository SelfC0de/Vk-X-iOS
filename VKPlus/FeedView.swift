import SwiftUI

struct FeedView: View {
    @State private var posts: [VKWallPost] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            Group {
                if isLoading {
                    ProgressView().tint(.cyberBlue)
                } else if let err = error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36)).foregroundStyle(Color.errorRed)
                        Text(err).foregroundStyle(Color.errorRed)
                            .multilineTextAlignment(.center).padding()
                        Button("Повторить") { Task { await load() } }
                            .foregroundStyle(Color.cyberBlue)
                    }
                } else if posts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 44)).foregroundStyle(Color.onSurfaceMut)
                        Text("Лента пуста").foregroundStyle(Color.onSurfaceMut)
                    }
                } else {
                    List(posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            if !post.text.isEmpty {
                                Text(post.text)
                                    .foregroundStyle(Color.onSurface)
                                    .font(.system(size: 14)).lineSpacing(2)
                            }
                            HStack(spacing: 12) {
                                Label("\(post.likesCount)", systemImage: "heart")
                                    .font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                                Text(Date(timeIntervalSince1970: TimeInterval(post.date)), style: .relative)
                                    .font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.surface)
                        .listRowSeparatorTint(Color.divider)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Лента")
        .navigationBarTitleDisplayMode(.inline)
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
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        do    { posts = try await VKAPIClient.shared.getNewsfeed() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}
