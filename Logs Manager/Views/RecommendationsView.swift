import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: LogStore

    @State private var isLoading = false
    @State private var report: String?
    @State private var errorMessage: String?
    @State private var snapshot: RecommendationSnapshot?
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatInput = ""
    @State private var isChatLoading = false

    var body: some View {
        VStack(spacing: 14) {
            Button {
                generateReport()
            } label: {
                Label(L10n.ru("Показать отчёт и рекомендации", en: "Show Report and Recommendations"), systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.ru("Формируем отчёт через DeepSeek…", en: "Generating report with DeepSeek…"))
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                ContentUnavailableView {
                    Label(L10n.ru("Не удалось сформировать отчёт", en: "Could Not Generate Report"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(cleanMarkdown(report))
                            .font(.system(size: 16))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Divider()

                        chatSection
                    }
                    .padding()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.ru("Вопросы по отчёту", en: "Questions about the Report"))
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(chatMessages.indices, id: \.self) { index in
                        let message = chatMessages[index]
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: message.role == "user" ? "person.circle" : "sparkles")
                            Text(cleanMarkdown(message.content))
                                .font(.system(size: 15))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(
                            message.role == "user"
                                ? Color.blue.opacity(0.10)
                                : Color.gray.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                }
            }
            .frame(maxHeight: 260)

            HStack(spacing: 8) {
                TextField(L10n.ru("Задайте вопрос", en: "Ask a question"), text: $chatInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendChat()
                    }

                Button(L10n.ru("Отправить", en: "Send")) {
                    sendChat()
                }
                .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChatLoading)
            }
        }
    }

    private func generateReport() {
        guard !settings.deepSeekAPIKey.isEmpty else {
            errorMessage = L10n.ru("Добавьте API-ключ DeepSeek в настройках приложения.", en: "Add a DeepSeek API key in Settings.")
            return
        }

        isLoading = true
        errorMessage = nil
        report = nil
        snapshot = nil
        chatMessages.removeAll()
        chatInput = ""

        Task {
            do {
                let logEntries = store.entries
                let historySamples = SystemLoadHistoryStore.shared.samples
                let newSnapshot = await Task.detached(priority: .utility) {
                    await RecommendationCollector.buildSnapshot(
                        logEntries: logEntries,
                        historySamples: historySamples
                    )
                }.value
                snapshot = newSnapshot

                let text = try await DeepSeekRecommendationService.generateReport(
                    snapshot: newSnapshot,
                    apiKey: settings.deepSeekAPIKey
                )
                report = text
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func sendChat() {
        guard let snapshot else { return }
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        chatInput = ""
        chatMessages.append(ChatMessage(role: "user", content: text))
        isChatLoading = true

        Task {
            do {
                let answer = try await DeepSeekRecommendationService.chat(
                    snapshot: snapshot,
                    apiKey: settings.deepSeekAPIKey,
                    history: chatMessages
                )
                chatMessages.append(ChatMessage(role: "assistant", content: answer))
            } catch {
                chatMessages.append(
                    ChatMessage(role: "assistant", content: L10n.ru("Не удалось получить ответ: \(error.localizedDescription)", en: "Could not get a response: \(error.localizedDescription)"))
                )
            }
            isChatLoading = false
        }
    }

    private func cleanMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "* ", with: "• ")
            .replacingOccurrences(of: "\n- ", with: "\n• ")
    }
}
