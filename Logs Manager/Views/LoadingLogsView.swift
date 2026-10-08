import SwiftUI

struct LoadingLogsView: View {
    let progress: LogLoadProgress?

    @State private var appeared = false
    @State private var shimmering = false
    @State private var colorCycle = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.96),
                    Color.accentColor.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
                .frame(width: 560, height: 340)

            VStack(spacing: 30) {
                Text(L10n.ru("Загружаем ваши логи", en: "Loading Your Logs"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink, .orange, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .hueRotation(.degrees(colorCycle ? 360 : 0))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .animation(.spring(response: 0.75, dampingFraction: 0.82), value: appeared)

                VStack(spacing: 12) {
                    progressBar

                    HStack {
                        Text(statusText)
                        Spacer()
                        if let progress, let total = progress.total, total > 0 {
                            Text(L10n.ru("\(progress.processed) из \(total)", en: "\(progress.processed) of \(total)"))
                                .monospacedDigit()
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 360)
            }
            .padding(48)
            .frame(width: 560, height: 340)
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
            withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: true)) {
                shimmering = true
            }
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                colorCycle = true
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                if let progress, let total = progress.total, total > 0 {
                    let fraction = min(max(CGFloat(progress.processed) / CGFloat(total), 0), 1)
                    Capsule()
                        .fill(barGradient)
                        .frame(width: proxy.size.width * fraction)
                        .animation(.easeOut(duration: 0.18), value: progress.processed)
                } else {
                    Capsule()
                        .fill(barGradient)
                        .frame(width: proxy.size.width * 0.34)
                        .offset(x: shimmering ? proxy.size.width * 0.66 : 0)
                }
            }
        }
        .frame(height: 10)
    }

    private var statusText: String {
        guard let progress else { return L10n.ru("Готовим системный журнал…", en: "Preparing system log…") }
        if progress.total == nil {
            return L10n.ru("Читаем данные системного журнала…", en: "Reading system log data…")
        }
        return L10n.ru("Обрабатываем записи…", en: "Processing entries…")
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
