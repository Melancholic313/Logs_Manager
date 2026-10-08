import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: BackgroundMonitor
    @State private var showBackgroundPicker = false

    var body: some View {
        Form {
            Section {
                Toggle(L10n.ru("Показывать уровни Debug и Info", en: "Show Debug and Info levels"), isOn: $settings.showDebugInfo)
                    .help(L10n.ru("По умолчанию отображаются только Default, Error и Fault.", en: "By default, only Default, Error, and Fault are shown."))
            } header: {
                Text(L10n.ru("Фильтрация", en: "Filtering"))
            } footer: {
                Text(L10n.ru("Включите этот параметр, если нужно видеть подробные технические записи уровней Debug и Info.", en: "Enable this to see detailed technical Debug and Info entries."))
            }

            LoadSettingsEditor(settings: $settings.taskManagerLoadSettings)

            Section {
                Toggle(L10n.ru("Показывать аннотации разделов приложения", en: "Show section annotations"), isOn: $settings.showSectionAnnotations)

                Picker(L10n.ru("Язык", en: "Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayTitle).tag(language)
                    }
                }

                HStack {
                    Label(
                        settings.background.title,
                        systemImage: "photo.on.rectangle.angled"
                    )

                    Spacer()

                    Button(L10n.ru("Выбрать фон", en: "Choose Background")) {
                        showBackgroundPicker = true
                    }
                }
            } header: {
                Text(L10n.ru("Внешний вид", en: "Appearance"))
            }

            Section {
                Picker(L10n.ru("Срок хранения истории нагрузки", en: "Load history retention"), selection: $settings.loadHistoryRetentionDays) {
                    Text(L10n.ru("3 дня", en: "3 days")).tag(3)
                    Text(L10n.ru("7 дней", en: "7 days")).tag(7)
                    Text(L10n.ru("14 дней", en: "14 days")).tag(14)
                    Text(L10n.ru("30 дней", en: "30 days")).tag(30)
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.ru("История нагрузки", en: "Load History"))
            } footer: {
                Text(L10n.ru("Используется для сравнения текущей нагрузки приложения с его обычной нагрузкой.", en: "Used to compare an app's current load with its normal load."))
            }

            Section {
                Toggle(L10n.ru("Запускать при входе", en: "Launch at Login"), isOn: $settings.launchAtLoginEnabled)
            } header: {
                Text(L10n.ru("Запуск", en: "Launch"))
            } footer: {
                Text(L10n.ru("Logs Manager будет автоматически запускаться при входе в macOS.", en: "Logs Manager will start automatically when you log in to macOS."))
            }

            Section {
                SecureField(L10n.ru("API-ключ DeepSeek", en: "DeepSeek API Key"), text: $settings.deepSeekAPIKey)
            } header: {
                Text(L10n.ru("Рекомендации", en: "Recommendations"))
            } footer: {
                Text(L10n.ru("Ключ хранится в Keychain и используется только при ручном формировании отчёта.", en: "The key is stored in Keychain and used only when you manually generate a report."))
            }

            Section {
                Picker(L10n.ru("Период индексации", en: "Indexing period"), selection: $settings.windowMinutes) {
                    Text(L10n.ru("10 минут", en: "10 minutes")).tag(10)
                    Text(L10n.ru("15 минут", en: "15 minutes")).tag(15)
                    Text(L10n.ru("30 минут", en: "30 minutes")).tag(30)
                    Text(L10n.ru("1 час", en: "1 hour")).tag(60)
                    Text(L10n.ru("3 часа", en: "3 hours")).tag(180)
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.ru("Индексация", en: "Indexing"))
            } footer: {
                Text(L10n.ru("Логи будут перечитываться при запуске и по кнопке «Обновить» за выбранный промежуток времени.", en: "Logs are re-read on launch and via Refresh for the selected period."))
            }

            Section {
                Toggle(L10n.ru("Работать в фоне", en: "Run in Background"), isOn: $settings.backgroundMonitoringEnabled)

                Toggle(L10n.ru("Уведомлять о критических сбоях (Fault)", en: "Notify about critical failures (Fault)"), isOn: $settings.notifyFault)
                    .disabled(!settings.backgroundMonitoringEnabled)
                    .opacity(settings.backgroundMonitoringEnabled ? 1 : 0.45)
                Toggle(L10n.ru("Уведомлять об ошибках (Error)", en: "Notify about errors (Error)"), isOn: $settings.notifyError)
                    .disabled(!settings.backgroundMonitoringEnabled)
                    .opacity(settings.backgroundMonitoringEnabled ? 1 : 0.45)
                Toggle(L10n.ru("Уведомлять о событиях (Default)", en: "Notify about events (Default)"), isOn: $settings.notifyDefault)
                    .disabled(!settings.backgroundMonitoringEnabled)
                    .opacity(settings.backgroundMonitoringEnabled ? 1 : 0.45)

                Toggle(
                    L10n.ru("Уведомлять о высокой нагрузке ЦПУ процессом", en: "Notify when a process uses high CPU"),
                    isOn: $settings.highCPUNotificationEnabled
                )
                .disabled(!settings.backgroundMonitoringEnabled)
                .opacity(settings.backgroundMonitoringEnabled ? 1 : 0.45)

                if let accessMessage = monitor.accessMessage {
                    Label(accessMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            } header: {
                Text(L10n.ru("Фоновые уведомления", en: "Background Notifications"))
            } footer: {
                Text(L10n.ru("Проверка журнала выполняется каждые 20 секунд и не нагружает процессор. Уведомления показываются даже при открытом приложении.", en: "Log checks run every 20 seconds without heavy CPU use. Notifications appear even while the app is open."))
            }
        }
        .formStyle(.grouped)
        .id(settings.language)
        .scrollContentBackground(settings.background.isCustom ? .hidden : .visible)
        .navigationTitle(L10n.ru("Настройки", en: "Settings"))
        .padding()
        .onAppear {
            monitor.configure(settings: settings)
        }
        .onChange(of: settings.backgroundMonitoringEnabled) { _, _ in
            monitor.configure(settings: settings)
        }
        .onChange(of: settings.notifyFault) { _, _ in
            monitor.configure(settings: settings)
        }
        .onChange(of: settings.notifyError) { _, _ in
            monitor.configure(settings: settings)
        }
        .onChange(of: settings.notifyDefault) { _, _ in
            monitor.configure(settings: settings)
        }
        .onChange(of: settings.highCPUNotificationEnabled) { _, _ in
            monitor.configure(settings: settings)
        }
        .onChange(of: settings.launchAtLoginEnabled) { _, newValue in
            LaunchAtLoginManager.setEnabled(newValue)
        }
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundPickerView(selection: $settings.background)
        }
    }
}

private struct BackgroundPickerView: View {
    @Binding var selection: AppBackground
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.ru("Выберите фон", en: "Choose Background"))
                .font(.title3.weight(.semibold))
                .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(AppBackground.allCases) { background in
                        Button {
                            selection = background
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                background.previewView
                                    .frame(width: 46, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                    }

                                Text(background.title)
                                    .font(.body)

                                Spacer()

                                if selection == background {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .background(
                                selection == background
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 360, height: 460)
    }
}
