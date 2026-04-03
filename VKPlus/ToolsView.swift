import SwiftUI

struct ToolsView: View {
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 44)).foregroundStyle(.onSurfaceMut)
                Text("Tools").foregroundStyle(.onSurfaceMut)
            }
        }
    }
}
