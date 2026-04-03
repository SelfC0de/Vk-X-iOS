import SwiftUI

struct AvatarView: View {
    let url:  String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlStr = url, let imageUrl = URL(string: urlStr) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        Color.surfaceVar
                            .overlay(ProgressView().tint(.cyberBlue).scaleEffect(0.6))
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.surfaceVar)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.onSurfaceMut)
                    .font(.system(size: size * 0.4))
            )
    }
}
