import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Logs Manager")
                    .font(.largeTitle.weight(.bold))

                Text(L10n.ru("Приложение для чтения и анализа системных логов macOS, мониторинга нагрузки CPU/GPU/RAM, записи/экспорта графиков, а также получения рекомендаций на основе искусственного интеллекта.", en: "An app for reading and analyzing macOS system logs, monitoring CPU/GPU/RAM load, recording/exporting charts, and getting AI-powered recommendations."))
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.ru("Возможности", en: "Features"))
                        .font(.title3.weight(.semibold))
                    Text(L10n.ru("• Просмотр и гуманизация unified log.", en: "• Unified log viewing and humanization."))
                    Text(L10n.ru("• Опасные паттерны: panic, crash, kernel, SIGABRT, memory pressure.", en: "• Dangerous patterns: panic, crash, kernel, SIGABRT, memory pressure."))
                    Text(L10n.ru("• Мониторинг нагрузки приложений и системы.", en: "• App and system load monitoring."))
                    Text(L10n.ru("• Диспетчер задач и запущенные программы.", en: "• Task manager and running apps."))
                    Text(L10n.ru("• Путешествие во времени по логам.", en: "• Log time travel."))
                    Text(L10n.ru("• Отчёты и рекомендации DeepSeek.", en: "• DeepSeek reports and recommendations."))
                    Text(L10n.ru("• Стресс-тест системы.", en: "• System stress test."))
                }
                .font(.system(size: 16))

                Text(L10n.ru("Подходит разработчикам, администраторам и продвинутым пользователям macOS, которым нужно быстро находить причины сбоев и следить за нагрузкой.", en: "Useful for developers, administrators, and advanced macOS users who need to find failure causes quickly and monitor load."))
                    .font(.system(size: 16))

                Button {
                    if let url = URL(string: "https://dalink.to/melancholic313") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(L10n.ru("Поддержать разработчика", en: "Support the Developer"), systemImage: "heart.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}
