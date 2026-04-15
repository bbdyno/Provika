import SwiftUI

struct RecordingIndicatorView: View {
    let elapsedTime: TimeInterval
    @State private var isBlinking = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .opacity(isBlinking ? 0.3 : 1.0)

            Text("REC")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.red)

            Text(formattedTime)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6))
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
        }
    }

    private var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
