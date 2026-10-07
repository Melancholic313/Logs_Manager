# Logs Manager

![Russian](https://img.shields.io/badge/lang-russian-blue)
![English](https://img.shields.io/badge/lang-english-green)

Logs Manager — это приложение для macOS, которое помогает читать и понимать системные журналы, следить за нагрузкой CPU/GPU/RAM, записывать графики нагрузки и получать рекомендации на основе искусственного интеллекта.
***
Logs Manager is a macOS application that helps you read and understand system logs, monitor CPU, GPU, and RAM usage, record load graphs, and receive AI-driven recommendations.

<img width="1470" height="839" alt="Снимок экрана — 2026-10-06 в 23 43 12" src="https://github.com/user-attachments/assets/6929cddb-7bbb-4901-9274-8a76bcc2ac09" />
<img width="2940" height="1672" alt="image" src="https://github.com/user-attachments/assets/38a9abba-b342-4b96-b32c-6481862788e5" />
<img width="2940" height="1674" alt="image" src="https://github.com/user-attachments/assets/852fe1cb-ec06-494c-8e01-d82509e2f117" />



## Важно / Important

Текущая сборка подписана **Ad-Hoc подписью**. Связано это с тем, что для полноценной подписи разработчика нужна **подписка для разработчиков от Apple за 99$ в год**, на что я пока не готов пойти. При первом запуске macOS может заблокировать приложение. Инструкция по первому запуску находится в конце файла.
***
The current build uses an **Ad-Hoc signature**. This is because a full developer signature requires an **Apple Developer Program subscription ($99/year)**, which I am not yet ready to purchase. macOS may block the application upon its first launch. Instructions for the initial launch can be found at the end of the file.


## Возможности / Possibilities

- Просмотр и гуманизация unified log macOS.
- Подсветка опасных паттернов: `panic`, `crash`, `kernel`, `SIGABRT`, `memory pressure`.
- Мониторинг нагрузки приложений и системы.
- Диспетчер задач с процессами, программами и цветовой индикацией нагрузки.
- Запись и экспорт графиков CPU/GPU/RAM в CSV и PNG.
- Путешествие во времени по логам.
- Отчёты и рекомендации через DeepSeek.
- Стресс-тест CPU/GPU.
- Фоновая работа из статус-меню macOS.
***
- Viewing and human-readable formatting of the macOS unified log.
- Highlighting of critical patterns: `panic`, `crash`, `kernel`, `SIGABRT`, `memory pressure`.
- Monitoring of application and system load.
- Task manager displaying processes and applications with color-coded load indicators.
- Recording and exporting CPU/GPU/RAM graphs to CSV and PNG.
- Log time-travel functionality.
- Reports and recommendations via DeepSeek.
- CPU/GPU stress testing.
- Background operation via the macOS status menu.


## Установка / Installation

Запустите скачанный Logs.Manager.dmg и переместите содежащийся там .app в папку /Applications. Первый запуск после установки потребует некоторых манипуляций (читать в **Первый запуск Ad-Hoc сборки**). Но проводится **однократно**, последующие запуски приложения будут происходить как обычно.
***
Run the downloaded Logs.Manager.dmg and move the .app file inside it to the /Applications folder. The first launch after installation requires a few extra steps (see **First launch of the Ad-Hoc build**). However, this is a **one-time** procedure; subsequent launches will proceed as usual.


## Поддержка разработчика / Developer support

Если приложение оказалось полезным, вы можете поддержать автора:
***
If you found the app useful, you can support the author:

[DonationAlerts](https://dalink.to/melancholic313)



## Первый запуск Ad-Hoc сборки / First launch of the Ad-Hoc build

1. Откройте Finder и перейдите в папку с `Logs Manager.app`.
2. Нажмите правой кнопкой мыши по приложению и выберите **Открыть**.
3. В появившемся окне снова нажмите **Открыть**.
4. После этого macOS запомнит разрешение для текущей сборки.

Если macOS по-прежнему блокирует приложение, откройте:

`Системные настройки → Конфиденциальность и безопасность`

и разрешите запуск `Logs Manager`.

Также можно снять атрибут карантина через терминал:

```sh
xattr -dr com.apple.quarantine "/path/to/Logs Manager.app"
```

Если нужно полностью удалить текущую Ad-Hoc подпись:

```sh
codesign --remove-signature "/path/to/Logs Manager.app"
```

После этого приложение будет запускаться как неподписанное, поэтому часть системных возможностей и нотаризация будут недоступны.

***

1. Open Finder and navigate to the folder containing `Logs Manager.app`.
2. Right-click the application and select **Open**.
3. Click **Open** again in the window that appears.
4. macOS will then remember this permission for the current build.

If macOS still blocks the application, go to:

`System Settings → Privacy & Security`

and allow `Logs Manager` to run.

You can also remove the quarantine attribute via Terminal:

```sh
xattr -dr com.apple.quarantine "/path/to/Logs Manager.app"
```

If you need to completely remove the current Ad-Hoc signature:

```sh
codesign --remove-signature "/path/to/Logs Manager.app"
```

The application will then launch as unsigned; consequently, some system features and notarization will be unavailable.
