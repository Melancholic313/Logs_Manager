import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LogRowView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var logExplanation: LogExplanationPresenter
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.messageType.iconName)
                .foregroundStyle(entry.messageType.tint)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(LogHumanizer.humanizedSentence(for: entry))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(entry.processName) · \(entry.subsystem) · \(entry.category)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !entry.eventMessage.isEmpty {
                    Text(entry.eventMessage)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 12)

            Text(entry.messageType.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(entry.messageType.tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(entry.messageType.tint.opacity(0.14)))
        }
        .padding(.vertical, 3)
        .listRowBackground(entry.isDangerous ? Color.red.opacity(0.12) : Color.clear)
        .overlay(alignment: .leading) {
            if entry.isDangerous {
                Rectangle()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 3)
            }
        }
        .contextMenu {
            Button {
                copyLogText()
            } label: {
                Label(L10n.ru("Копировать текст лога", en: "Copy Log Text"), systemImage: "doc.on.doc")
            }

            Button {
                saveLog()
            } label: {
                Label(L10n.ru("Сохранить…", en: "Save…"), systemImage: "square.and.arrow.down")
            }

            Divider()

            Button {
                explainLog()
            } label: {
                Label(L10n.ru("Что за лог?", en: "What is this log?"), systemImage: "questionmark.bubble")
            }
        }
    }

    private var logText: String {
        var lines = [LogHumanizer.humanizedSentence(for: entry)]
        lines.append(L10n.ru("Процесс: \(entry.processName)", en: "Process: \(entry.processName)"))
        lines.append(L10n.ru("Подсистема: \(entry.subsystem)", en: "Subsystem: \(entry.subsystem)"))
        lines.append(L10n.ru("Категория: \(entry.category)", en: "Category: \(entry.category)"))
        lines.append(L10n.ru("Уровень: \(entry.messageType.rawValue)", en: "Level: \(entry.messageType.rawValue)"))
        if !entry.eventMessage.isEmpty {
            lines.append(L10n.ru("Сообщение: \(entry.eventMessage)", en: "Message: \(entry.eventMessage)"))
        }
        lines.append(L10n.ru("Время: \(LogEntry.timestampFormatter.string(from: entry.timestamp))", en: "Time: \(LogEntry.timestampFormatter.string(from: entry.timestamp))"))
        return lines.joined(separator: "\n")
    }

    private func copyLogText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
    }

    private func saveLog() {
        let panel = NSSavePanel()
        panel.title = L10n.ru("Сохранить текст лога", en: "Save Log Text")
        panel.prompt = L10n.ru("Сохранить", en: "Save")
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(entry.processName)_лог.txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? logText.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    private func explainLog() {
        guard !settings.deepSeekAPIKey.isEmpty else {
            logExplanation.showError(
                L10n.ru("Добавьте API-ключ DeepSeek в настройках.", en: "Add a DeepSeek API key in Settings.")
            )
            return
        }

        logExplanation.show(
            logText: logText,
            apiKey: settings.deepSeekAPIKey
        )
    }
}

private struct LogExplanationSheet: View {
    let text: String?
    let error: String?
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(L10n.ru("Ищем ответ", en: "Looking for an answer"))
                        .font(.headline)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.ru("Что за лог?", en: "What is this log?"))
                        .font(.title3.weight(.semibold))

                    if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    } else if let text {
                        ScrollView {
                            Text(text)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 460, height: 320)
    }
}
