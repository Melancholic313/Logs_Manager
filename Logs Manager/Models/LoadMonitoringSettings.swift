import Foundation
import SwiftUI

enum LoadContentMode: String, CaseIterable, Identifiable, Codable {
    case text
    case graph
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: L10n.ru("Текст", en: "Text")
        case .graph: L10n.ru("Графики", en: "Charts")
        case .both: L10n.ru("Текст и графики", en: "Text and Charts")
        }
    }

    var includesText: Bool { self == .text || self == .both }
    var includesGraph: Bool { self == .graph || self == .both }
}

enum LoadGraphResolution: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: L10n.ru("Низкая", en: "Low")
        case .medium: L10n.ru("Средняя", en: "Medium")
        case .high: L10n.ru("Высокая", en: "High")
        }
    }

    var pointCount: Int {
        switch self {
        case .low: 60
        case .medium: 180
        case .high: 360
        }
    }

    var displayStride: Int {
        switch self {
        case .low: 4
        case .medium: 2
        case .high: 1
        }
    }
}

struct LoadRecordingSettings: Codable, Equatable {
    var contentMode: LoadContentMode = .both
    var textIntervalSeconds: TimeInterval = 2
    var graphIntervalSeconds: TimeInterval = 5
    var graphResolution: LoadGraphResolution = .medium
    var saveDirectoryPath: String?

    static let textIntervalOptions: [TimeInterval] = [0.5, 1, 2, 5, 10, 30]
    static let graphIntervalOptions: [TimeInterval] = [1, 2, 5, 10, 30, 60]
}

struct LoadSettingsEditor: View {
    @Binding var settings: LoadRecordingSettings
    var includeSaveLocation = true
    var contentLabel = L10n.ru("Содержимое записи и экспорта", en: "Recording and Export Content")

    var body: some View {
        Group {
            Section {
                Picker(contentLabel, selection: $settings.contentMode) {
                    ForEach(LoadContentMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.ru("Запись и экспорт", en: "Recording and Export"))
            }

            Section {
                Picker(L10n.ru("Дискретность графиков", en: "Chart Resolution"), selection: $settings.graphResolution) {
                    ForEach(LoadGraphResolution.allCases) { resolution in
                        Text(resolution.title).tag(resolution)
                    }
                }
                .pickerStyle(.menu)

                Picker(L10n.ru("Период записи текста", en: "Text Recording Interval"), selection: textIntervalBinding) {
                    ForEach(LoadRecordingSettings.textIntervalOptions, id: \.self) { seconds in
                        Text(Self.intervalTitle(seconds)).tag(seconds)
                    }
                }
                .pickerStyle(.menu)

                Picker(L10n.ru("Период записи графиков", en: "Chart Recording Interval"), selection: graphIntervalBinding) {
                    ForEach(LoadRecordingSettings.graphIntervalOptions, id: \.self) { seconds in
                        Text(Self.intervalTitle(seconds)).tag(seconds)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.ru("Точность и периодичность", en: "Precision and Frequency"))
            } footer: {
                Text(L10n.ru("Дискретность определяет, сколько последних точек сохраняется и с каким шагом отрисовываются графики в реальном времени и при экспорте. Периоды записи задают минимальный интервал между сохранением текстовых строк и PNG-снимков графиков.", en: "Resolution controls how many recent points are kept and how charts are drawn live/exported. Recording intervals set the minimum delay between text rows and PNG snapshots."))
            }

            if includeSaveLocation {
                Section {
                    HStack {
                        Label(
                            settings.saveDirectoryPath.map {
                                URL(fileURLWithPath: $0).lastPathComponent
                            } ?? L10n.ru("Папка не выбрана", en: "No Folder Selected"),
                            systemImage: "folder"
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)

                        Spacer()

                        Button(L10n.ru("Выбрать…", en: "Choose…")) {
                            chooseDirectory()
                        }
                    }
                } header: {
                    Text(L10n.ru("Место сохранения", en: "Save Location"))
                } footer: {
                    Text(L10n.ru("Сюда будут автоматически сохраняться файлы записи. Для экспорта всегда можно выбрать отдельный файл или папку.", en: "Recording files are saved here automatically. You can always choose a separate file or folder for export."))
                }
            }
        }
    }

    private var textIntervalBinding: Binding<TimeInterval> {
        Binding(
            get: { settings.textIntervalSeconds },
            set: { settings.textIntervalSeconds = $0 }
        )
    }

    private var graphIntervalBinding: Binding<TimeInterval> {
        Binding(
            get: { settings.graphIntervalSeconds },
            set: { settings.graphIntervalSeconds = $0 }
        )
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = L10n.ru("Выберите папку для записей нагрузки", en: "Choose a folder for load recordings")
        panel.prompt = L10n.ru("Выбрать", en: "Choose")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            settings.saveDirectoryPath = url.path
        }
    }

    private static func intervalTitle(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return L10n.ru("0,5 с", en: "0.5 sec")
        }
        if seconds.truncatingRemainder(dividingBy: 1) == 0 {
            return L10n.ru("\(Int(seconds)) с", en: "\(Int(seconds)) sec")
        }
        return L10n.ru(String(format: "%.1f с", seconds), en: String(format: "%.1f sec", seconds))
    }
}
