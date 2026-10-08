import SwiftUI
import Charts
import AppKit

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

struct LoadGraphHeader {
    let title: String?
    let subtitle: String?
    let timestamp: Date?
}

struct LoadGraphsView: View {
    let systemHistory: [LoadHistoryPoint]
    let processHistory: [LoadHistoryPoint]
    let processName: String?
    let includeSystem: Bool
    let graphResolution: LoadGraphResolution
    let header: LoadGraphHeader?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 14) {
            if let header {
                graphHeader(header)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                if includeSystem {
                    metricChart(
                        title: L10n.ru("ЦПУ — система", en: "CPU — System"),
                        points: systemHistory,
                        color: .blue,
                        unit: "%",
                        value: \.cpu
                    )
                    metricChart(
                        title: L10n.ru("ГПУ — система", en: "GPU — System"),
                        points: systemHistory,
                        color: .purple,
                        unit: "%",
                        value: \.gpu
                    )
                    metricChart(
                        title: L10n.ru("ОЗУ — система", en: "RAM — System"),
                        points: systemHistory,
                        color: .green,
                        unit: L10n.ru("МБ", en: "MB"),
                        value: \.memoryMB
                    )
                }

                if let processName, !processHistory.isEmpty {
                    metricChart(
                        title: L10n.ru("ЦПУ — \(processName)", en: "CPU — \(processName)"),
                        points: processHistory,
                        color: .cyan,
                        unit: "%",
                        value: \.cpu
                    )
                    metricChart(
                        title: L10n.ru("ГПУ — \(processName)", en: "GPU — \(processName)"),
                        points: processHistory,
                        color: .pink,
                        unit: "%",
                        value: \.gpu
                    )
                    metricChart(
                        title: L10n.ru("ОЗУ — \(processName)", en: "RAM — \(processName)"),
                        points: processHistory,
                        color: .orange,
                        unit: L10n.ru("МБ", en: "MB"),
                        value: \.memoryMB
                    )
                }
            }
        }
        .padding(14)
    }

    private func graphHeader(_ header: LoadGraphHeader) -> some View {
        VStack(spacing: 3) {
            if let title = header.title, !title.isEmpty {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if let subtitle = header.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let timestamp = header.timestamp {
                Text(Self.headerDateFormatter.string(from: timestamp))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private func sampledPoints(_ points: [LoadHistoryPoint]) -> [LoadHistoryPoint] {
        guard graphResolution.displayStride > 1, points.count > 2 else {
            return points
        }

        let step = graphResolution.displayStride
        var sampled = Swift.stride(from: 0, to: points.count, by: step).map { points[$0] }
        if sampled.last?.id != points.last?.id {
            sampled.append(points[points.count - 1])
        }
        return sampled
    }

    private func metricChart(
        title: String,
        points: [LoadHistoryPoint],
        color: Color,
        unit: String,
        value: KeyPath<LoadHistoryPoint, Double>
    ) -> some View {
        let points = sampledPoints(points)

        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart(points) { point in
                LineMark(
                    x: .value(L10n.ru("Время", en: "Time"), point.timestamp),
                    y: .value(title, point[keyPath: value])
                )
                .foregroundStyle(color)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value(L10n.ru("Время", en: "Time"), point.timestamp),
                    y: .value(title, point[keyPath: value])
                )
                .foregroundStyle(color.opacity(0.55))
                .symbolSize(8)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 150)
            .chartYAxisLabel(unit)
        }
    }

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return formatter
    }()
}

@MainActor
enum LoadGraphRenderer {
    static func renderImage(
        systemHistory: [LoadHistoryPoint],
        processHistory: [LoadHistoryPoint],
        processName: String?,
        includeSystem: Bool,
        graphResolution: LoadGraphResolution,
        header: LoadGraphHeader?
    ) -> NSImage? {
        let content = LoadGraphsView(
            systemHistory: systemHistory,
            processHistory: processHistory,
            processName: processName,
            includeSystem: includeSystem,
            graphResolution: graphResolution,
            header: header
        )
        .padding(20)
        .frame(width: 1180, height: 820)
        .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return renderer.nsImage
    }
}
