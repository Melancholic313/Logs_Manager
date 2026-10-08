# Logs Manager — Project Notes

## What this project is

macOS SwiftUI app for reading and humanizing the unified system log, monitoring
per-process CPU/GPU/RAM load, and recording/exporting that load as CSV and PNG
charts. UI language is Russian.

## Important build facts

- Xcode project: `Logs Manager.xcodeproj`
- Scheme: `MyApp`
- The project uses `PBXFileSystemSynchronizedRootGroup`, so new Swift files
  placed under `Logs Manager/` are picked up automatically. Do not edit
  `project.pbxproj` manually to register source files.
- Build target defaults:
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES`
  - `SWIFT_VERSION = 5.0`
  - `ENABLE_APP_SANDBOX = NO`
  - `ENABLE_HARDENED_RUNTIME = YES`
- Reliable CLI build command:
  ```sh
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
    -project 'Logs Manager.xcodeproj' \
    -scheme MyApp \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath /tmp/lm-dd \
    CODE_SIGNING_ALLOWED=NO build
  ```
- SwiftUI macro plugins cannot run inside the default sandbox. If a build fails
  with `swift-plugin-server produced malformed response`, rerun the build with
  escalated/unsandboxed permissions.

## Main architecture

- Entry point: `Logs Manager/MyApp.swift`
- Root UI: `Logs Manager/ContentView.swift`
- Sidebar tabs: `Logs Manager/Views/SidebarView.swift`
- Models:
  - `Models/LogModels.swift` — `LogEntry`, `LogLevel`, `LogGroup`, `LogTab`
  - `Models/LogStore.swift` — log index state and `refresh()`
  - `Models/AppSettings.swift` — persisted user settings and backgrounds
  - `Models/LoadMonitoringSettings.swift` — load recording settings UI/model
- Log services:
  - `Services/LogReader.swift` — runs `/usr/bin/log show --style ndjson`
  - `Services/AppLogReader.swift` — per-PID log reading
  - `Services/LogHumanizer.swift` — Russian human-readable log text
  - `Services/BackgroundMonitor.swift` — background notifications
- Load monitoring:
  - `Services/ProcessMetrics.swift` — raw process CPU/GPU/RAM sampling
  - `Services/LoadMonitoringSession.swift` — sampling timer, recording, export
  - `Views/LoadCharts.swift` — Swift Charts rendering and PNG export
  - `Views/TaskManagerView.swift` — task-manager tab

## Current features

- Sidebar is a flat `List` with `Меню` and, while editing, `Скрытые пункты меню`.
- `LogTab.taskManager` is the task manager tab.
- `LogTab.dangerousPatterns` is a log tab collecting panic/crash/kernel/SIGABRT/
  memory-pressure entries regardless of log level.
- `AppLogsView` has two segments: `logs` and `load`.
- The `.appLogs` tab title is `Мониторинг приложений`.
- Task-manager load settings are stored in `AppSettings.taskManagerLoadSettings`.
- App-logs load settings are isolated in `AppSettings.appLogsLoadSettings` and
  are edited from the popover behind `Настройки мониторинга нагрузки`.
- The selected PID in `AppLogsView` is owned by `RootView` via
  `@State appLogsSelectedPID` and passed as a `Binding`. This keeps the last
  selected app during the current app session without running monitoring in the
  background while the tab is closed.
- Load recording settings are `LoadRecordingSettings` with:
  - `contentMode`: text, graph, both
  - `graphResolution`: low/medium/high
  - `textIntervalSeconds`
  - `graphIntervalSeconds`
  - `saveDirectoryPath`
- `LoadGraphResolution` now has both `pointCount` (history retention) and
  `displayStride` (real-time chart downsampling), so `Дискретность` affects
  live display as well as recorded/exported PNGs.
- Recorded/exported PNGs can have a `LoadGraphHeader` with app name, app
  version, and snapshot timestamp. App-logs recording passes this header from
  `AppLogsView`; task manager currently passes `nil`.
- `LogEntry.isDangerous` is computed from `panic`, `crash`, `kernel`, `sigabrt`,
  and `memory pressure`. Dangerous rows get a red left bar and light red row
  background in `LogRowView`.
- CPU per process: `proc_pid_rusage(RUSAGE_INFO_V4)` using
  `ri_user_time + ri_system_time`, delta / elapsed wall time.
- GPU per process: `task_info(TASK_POWER_INFO_V2)` ->
  `task_gpu_utilisation`, delta / elapsed wall time. Protected processes may
  return no GPU and are shown as `—`.
- Memory per process: `ri_phys_footprint`.
- System CPU: `host_statistics64(HOST_CPU_LOAD_INFO)`.
- System memory: `host_statistics64(HOST_VM_INFO64)` + `physicalMemory`.

## Known gotchas

- Heavy `ProcessMetricsReader.capture()` should never run while `LogStore.isLoading`
  is true. `TaskManagerView` intentionally pauses load monitoring until log
  indexing finishes.
- `ProcessMetricsReader` methods are marked `nonisolated` because the project
  defaults to MainActor isolation and the sampler runs on a detached background
  task.
- `proc_pid_rusage` is imported oddly (`UnsafeMutablePointer<rusage_info_t?>`),
  but it must receive the address of the concrete `rusage_info_v4` struct, not
  the address of a separate pointer variable. The correct pattern is in
  `ProcessMetricsReader.capture()` using `withMemoryRebound` over
  `rusage_info_v4`/`rusage_info_t?` memory. Passing `&somePointerVariable`
  causes stack-canary failure (`SIGABRT`) and an apparent app hang.
- `NSImage` has a custom `pngData()` helper in `Views/LoadCharts.swift`.
- Custom backgrounds force dark color scheme in `ContentView.swift` so black
  primary text stays readable over dark gradients during light system mode.
- Added two Liquid Glass-style backgrounds: `liquidSage` (`Li · Шалфей`) and
  `liquidDusk` (`Li · Сумерки`) in `AppBackground`; their display titles were
  later shortened to `Шалфей` and `Сумерки`.
- `AppBackground` also exposes `previewView`, a compact non-ignoring-safe-area
  version used by the background picker.
- `TaskManagerView` includes a `Запущенные программы` panel next to the process
  table. Soft quit uses `NSRunningApplication.terminate()`, force quit uses
  `forceTerminate()` after a `confirmationDialog`.
- The first graph snapshot during recording is intentionally skipped in
  `LoadRecorder.record()` because it is normally empty.
- `SidebarView` uses `matchedGeometryEffect` (`sidebar-selection`) so the
  active-tab highlight animates between tabs instead of jumping.
- Sidebar tab order and hidden tabs are persisted in `AppSettings`:
  `sidebarVisibleTabs` and `sidebarHiddenTabs`. `SidebarView` has an edit mode
  with drag-and-drop reordering and a `Скрытые пункты меню` drop zone.
- When loading persisted sidebar state, `AppSettings` reads hidden tabs first
  and excludes them from the visible-tab fallback merge, so hidden items do not
  reappear in the visible list after restart.
- `LogRowView` provides a custom context menu with `Копировать текст лога` and
  `Сохранить…` instead of the stock macOS menu.
- Background notifications attach the same rounded dock-style app icon via
  `BackgroundMonitor.attachAppIcon(to:)` and a temporary PNG attachment.
- `LogStore` caches `allLogGroups` and `allLogGroupsWithDebug` so opening
  `Все логи` does not re-group thousands of entries on every appearance.
- `TaskManagerView` starts `LoadMonitoringSession` with
  `processListRefreshInterval: 3.0`, so the process table updates less often
  than raw sampling/history and reduces scroll jank. The process table uses a
  `LazyVStack` with a cached sorted array (`sortedProcessCache`) instead of an
  eager `Grid`.
- Sidebar reordering inside visible/hidden sections uses native List `.onMove`
  so the dragged row itself follows the cursor. Cross-section hide/restore uses
  both the left-side drag handle and the item title with `.onDrag`, then List
  `.onInsert(of:)` inserts at the exact drop index.
- Sidebar drag reordering is disabled outside edit mode via
  `.moveDisabled(!isEditing)` and `onDrag` guards, so normal mode only allows
  tab selection, not accidental reordering.
- The sidebar edit button is styled like a normal sidebar row: 18pt icon frame,
  white icon color, caption text, and matching vertical padding.
- Settings background selection uses a `BackgroundPickerView` sheet with live
  gradient previews instead of a menu picker.
- `AppSettings.showSectionAnnotations` controls reusable `SectionAnnotationView`
  banners rendered above the active section in `ContentView`.
- `AppSettings.highCPUNotificationEnabled` enables a separate 20-second
  background CPU sampler in `BackgroundMonitor`. It notifies when a process
  stays above 80% CPU for more than 30 seconds, with a 5-minute per-process
  cooldown. It only runs when `backgroundMonitoringEnabled` is also enabled.
- `AppLoadHistoryStore` stores lightweight daily CPU aggregates per app in
  Application Support, throttled to save at most once per minute. It is used by
  `AppLogsView` to compare today's CPU with the previous
  `loadHistoryRetentionDays` days.
- `AppSettings.launchAtLoginEnabled` uses `SMAppService.mainApp` via
  `Services/LaunchAtLoginManager.swift`. The manager no longer exposes a
  `status` property, so no SMAppService/Shortcuts XPC query is made merely by
  importing or loading the manager; the system call happens only when the user
  toggles `Запускать при входе`.
- `AppDelegate` intercepts Cmd+Q in `applicationShouldTerminate`: unless
  `AppDelegate.shouldTerminateOnQuit` was set by the status-menu `Выйти`
  button, it closes windows, switches to accessory activation policy, and
  cancels termination. Closing the window hides the Dock icon while the menu-bar
  app stays alive.
- `AppActivityState.shared` tracks whether a window is visible. When no window
  is visible, `BackgroundMonitor` sleeps 60 seconds instead of 20, and
  `SystemLoadHistoryStore` samples at most every 30 seconds using background QoS
  instead of 15-second utility QoS.
- `StatusMenuView` uses `StatusMenuSampler` to show a compact CPU sparkline,
  memory usage, and top process while the menu is open.
- `TimeTravelView` is a lightweight time-travel tab backed by
  `Services/TimeTravelStore.swift`. It loads the full selected `startDate...endDate`
  period once via `LogReader.load(between:and:)`, then replays the cached logs
  with a progress slider; playback never calls `LogReader` again. Its store lives
  in `RootView` so loaded data survives tab switches within the app session.
- `TimeTravelView` is top-aligned to avoid the empty-state UI shifting vertically.
  Paused timeline changes show only the current 5-second bucket and force a List
  identity update so stale rows are cleared.
- `TimeTravelView` also shows a live current-system CPU/GPU/RAM card using
  `StatusMenuSampler` while the tab is open. Those samples are stored in
  `TimeTravelStore.loadSamples` and the nearest recorded sample to the current
  timeline position is displayed, rather than always showing live system load.
- System load history is now collected globally by
  `SystemLoadHistoryStore.shared` (started in `AppDelegate`) every 15 seconds.
  `TimeTravelView` picks the nearest recorded `SystemLoadSample` for the current
  timeline position instead of showing live values.
- macOS unified logs do not expose reliable historical CPU/GPU/RAM load, so
  `TimeTravelView` no longer renders a CPU/GPU/RAM card. The global recorder
  remains available for future use, but time travel is log-focused.
- Time-travel log buckets use 5-second buckets and keep at most 12 entries per
  bucket; parsing no longer stops after 12k lines, so the full selected period
  is represented.
- Time-travel streaming parser state is wrapped in a locked
  `TimeTravelParser` class with `nonisolated(unsafe)` data properties, so the
  old captured-var concurrency warnings are gone and the code is Swift 6-safe.
- Time-travel playback starts at the beginning by default, resumes from the
  current position after pause, and only restarts from zero when it reaches the
  end. The speed label is rendered separately from the segmented picker so it
  is never clipped.
- Time-travel speed is now a menu with true timeline speeds: x1, x2, x5, x10,
  x60, x100.
- `RecommendationsView` manually builds a DeepSeek report using model
  `deepseek-flash`. The API key is stored in Keychain via
  `Services/KeychainStore.swift` and exposed through
  `AppSettings.deepSeekAPIKey`.
- After the initial report, `RecommendationsView` keeps the snapshot and offers
  a chat section. Chat messages are retained until a new report is generated.
  The `DeepSeekRecommendationService.chat` endpoint includes the same system
  snapshot as the report, so follow-up answers have the original context.
- Markdown stars/headers are lightly cleaned in `RecommendationsView` before
  showing the report and chat answers.
- `RecommendationCollector` is nonisolated and its potentially slow 10-second
  fallback sampling runs in a detached task, not on the MainActor, to avoid
  WindowServer unresponsive events during report generation.
- DeepSeek prompts are tuned to treat Logs Manager leniently: the system is told
  the app runs with an Ad-Hoc signature, so XPC/TCC denials for Logs Manager
  should be reported as a signing limitation, not suspicious software.
- `Services/RecommendationCollector.swift` gathers a compact snapshot:
  recent system-load samples, top 10 processes, and up to 20 unique error/fault
  logs. User paths are sanitized to `/Users/[user]/`.
- `TaskManagerView` shows a flat color status panel with green/yellow/red load
  level and a short label.
- `LogRowView` has a `Что за лог?` context action that calls
  `DeepSeekRecommendationService.explainLog` and shows a dimming sheet.
- The explanation sheet was replaced with a global `LogExplanationOverlay`
  backed by `LogExplanationPresenter`, shown in `RootView`. It supports outside
  click dismissal and `Esc` via `onExitCommand`.
- While the explanation request is loading, `LogExplanationSheet` shows a large
  spinner and `Ищем ответ`/`Looking for an answer` instead of the title.
- The explanation sheet is given `.id(isExplaining)` so SwiftUI recreates it
  when loading state changes, making the spinner state visible reliably.
- `LogRowView` intentionally does not use `.textSelection(.enabled)` because
  macOS otherwise shows the system Font/Spelling context menu instead of the
  custom log context menu.
- `StressTestView` provides manual CPU stress by spawning `/bin/zsh -lc "yes"`,
  stops all child processes, shows a live CPU chart, and can export a text
  report. GPU stress currently shows an unsupported-in-this-build message.
- `AboutView` and `README.md` describe the app and link to DonationAlerts.
- Localization foundation was added via `AppLanguage`, `L10n`, and
  `AppSettings.language`. The language picker is in Settings and defaults to
  system language (Russian if preferred language is Russian, otherwise
  English). Translated so far: sidebar titles/annotations, Settings, Status
  Menu, Loading Logs, About, Stress Test, Time Travel, Log Row context menu,
  Log List, Search toolbar, Task Manager headers/buttons/alerts/panels, most
  AppLogsView strings, and many service messages in BackgroundMonitor and
  LoadMonitoringSession. `LogHumanizer` subsystem/category dictionaries are now
  localized with English fallbacks. `LogReader`, `AppLogReader`, DeepSeek,
  `LoadCharts`, `BackgroundMonitor`, recommendations strings, load-recording
  settings, background titles, loading progress, and the refresh command are
  also localized.
- `AppLanguage.setOverride` is called by `AppSettings` on init and language
  changes, so `L10n.ru` immediately respects the user-selected language instead
  of relying only on `UserDefaults` reads.
- Settings and app-logs load editors use `.id(settings.language)` to force
  SwiftUI to recreate their form content when the language changes, preventing
  stale labels after switching back to Russian.
- Time-unit options in Settings/AppLogs/LoadRecordingSettings are localized:
  seconds, minutes, hours, and days now switch to English labels.
- `LogReader` has `load(between:and:)` for exact past date ranges in addition to
  the normal `load(window:)`.
- In sidebar edit mode, double-clicking an item toggles it between visible and
  hidden lists via `toggleHiddenState`.
- Empty visible/hidden sections show temporary drop-zone cards so there is
  always a drop target. `SidebarView` keeps `lastVisiblePosition` and
  `lastHiddenPosition` dictionaries so double-click restore inserts an item at
  its previous position.
