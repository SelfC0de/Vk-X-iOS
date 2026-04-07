import SwiftUI

// MARK: - Circular Download Button (AppStore style)
// Shows download icon → circular progress ring → checkmark on done
struct CircularDownloadButton: View {
    let urlStr: String
    let size: CGFloat
    let iconColor: Color
    let onTap: () -> Void

    @ObservedObject private var dm = DownloadManager.shared

    private var progress: Double? { dm.progress[urlStr] }
    private var isDownloading: Bool { progress != nil }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: size, height: size)

                if isDownloading {
                    // Track ring
                    Circle()
                        .stroke(iconColor.opacity(0.25), lineWidth: size * 0.09)
                        .frame(width: size * 0.72, height: size * 0.72)
                    // Progress ring — AppStore style
                    Circle()
                        .trim(from: 0, to: CGFloat(progress ?? 0))
                        .stroke(iconColor,
                                style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                        .frame(width: size * 0.72, height: size * 0.72)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                    // Stop icon (tap to cancel)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(iconColor)
                        .frame(width: size * 0.22, height: size * 0.22)
                } else {
                    // Download arrow
                    Image(systemName: "arrow.down")
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline circular progress (for list rows without tap-to-cancel)
struct CircularProgress: View {
    let progress: Double
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: size * 0.1)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
        }
        .frame(width: size, height: size)
    }
}
