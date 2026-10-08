import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject private var settings: AppSettings
    @Binding var selection: LogTab?

    @Namespace private var selectionAnimation
    @State private var isEditing = false
    @State private var draggedTab: LogTab?
    @State private var lastVisiblePosition: [LogTab: Int] = [:]
    @State private var lastHiddenPosition: [LogTab: Int] = [:]

    var body: some View {
        List {
            Section {
                if isEditing, settings.sidebarVisibleTabs.isEmpty {
                    visibleDropZone
                }

                ForEach(settings.sidebarVisibleTabs) { tab in
                    tabRow(tab, hidden: false)
                }
                .onMove(perform: moveVisible)
                .onInsert(of: [UTType.text]) { index, _ in
                    handleInsert(at: index, intoHidden: false)
                }
                .moveDisabled(!isEditing)
            } header: {
                Text(L10n.ru("Меню", en: "Menu"))
            }

            if isEditing {
                Section {
                    if settings.sidebarHiddenTabs.isEmpty {
                        hiddenDropZone
                    }

                    ForEach(settings.sidebarHiddenTabs) { tab in
                        tabRow(tab, hidden: true)
                    }
                    .onMove(perform: moveHidden)
                    .onInsert(of: [UTType.text]) { index, _ in
                        handleInsert(at: index, intoHidden: true)
                    }
                } header: {
                    Text(L10n.ru("Скрытые пункты меню", en: "Hidden Menu Items"))
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            editButton
        }
        .listStyle(.sidebar)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }

    private var editButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isEditing.toggle()
                draggedTab = nil
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                    .frame(width: 18)
                    .foregroundStyle(.white)
                Text(isEditing ? L10n.ru("Готово", en: "Done") : L10n.ru("Редактировать", en: "Edit"))
                Spacer(minLength: 0)
            }
            .font(.caption)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var visibleDropZone: some View {
        dropZone(title: L10n.ru("Перетащите сюда, чтобы отобразить", en: "Drop here to show"), systemImage: "arrow.up.to.line") {
            handleZoneDrop(toHidden: false)
        }
    }

    private var hiddenDropZone: some View {
        dropZone(title: L10n.ru("Перетащите сюда, чтобы скрыть", en: "Drop here to hide"), systemImage: "tray.and.arrow.down") {
            handleZoneDrop(toHidden: true)
        }
    }

    private func dropZone(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
            Text(title)
                .font(.caption)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.tertiary)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .onDrop(of: [UTType.text], isTargeted: Binding.constant(false)) { _ in
            action()
            return true
        }
    }

    private func tabRow(_ tab: LogTab, hidden: Bool) -> some View {
        HStack(spacing: 8) {
            if isEditing {
                Image(systemName: hidden ? "arrow.up.to.line" : "tray.and.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .onDrag {
                        draggedTab = tab
                        return NSItemProvider(object: tab.rawValue as NSString)
                    }
            }

            Image(systemName: tab.iconName)
                .frame(width: 18)
            Text(tab.title)
                .lineLimit(1)
                .onDrag {
                    guard isEditing else { return NSItemProvider() }
                    draggedTab = tab
                    return NSItemProvider(object: tab.rawValue as NSString)
                }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background {
            if !hidden, selection == tab {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                    .matchedGeometryEffect(id: "sidebar-selection", in: selectionAnimation)
            }
        }
        .opacity(hidden ? 0.62 : 1)
        .onTapGesture {
            guard !isEditing else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = tab
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                guard isEditing else { return }
                toggleHiddenState(tab)
            }
        )
    }

    private func moveVisible(from source: IndexSet, to destination: Int) {
        guard isEditing else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            settings.sidebarVisibleTabs.move(fromOffsets: source, toOffset: destination)
            for (position, tab) in settings.sidebarVisibleTabs.enumerated() {
                lastVisiblePosition[tab] = position
            }
        }
    }

    private func toggleHiddenState(_ tab: LogTab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            if settings.sidebarVisibleTabs.contains(tab) {
                let sourceIndex = settings.sidebarVisibleTabs.firstIndex(of: tab) ?? 0
                lastVisiblePosition[tab] = sourceIndex

                var visible = settings.sidebarVisibleTabs
                visible.removeAll { $0 == tab }
                settings.sidebarVisibleTabs = visible

                var hidden = settings.sidebarHiddenTabs
                let insertionIndex = lastHiddenPosition[tab].map {
                    min(max($0, 0), hidden.count)
                } ?? hidden.endIndex
                hidden.insert(tab, at: insertionIndex)
                settings.sidebarHiddenTabs = hidden
            } else if settings.sidebarHiddenTabs.contains(tab) {
                let sourceIndex = settings.sidebarHiddenTabs.firstIndex(of: tab) ?? 0
                lastHiddenPosition[tab] = sourceIndex

                var hidden = settings.sidebarHiddenTabs
                hidden.removeAll { $0 == tab }
                settings.sidebarHiddenTabs = hidden

                var visible = settings.sidebarVisibleTabs
                let insertionIndex = lastVisiblePosition[tab].map {
                    min(max($0, 0), visible.count)
                } ?? visible.endIndex
                visible.insert(tab, at: insertionIndex)
                settings.sidebarVisibleTabs = visible
            }
        }
    }

    private func handleInsert(at index: Int, intoHidden targetIsHidden: Bool) {
        guard isEditing, let draggedTab else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            let sourceIsHidden = settings.sidebarHiddenTabs.contains(draggedTab)

            if sourceIsHidden != targetIsHidden {
                if sourceIsHidden {
                    let sourceIndex = settings.sidebarHiddenTabs.firstIndex(of: draggedTab) ?? 0
                    lastHiddenPosition[draggedTab] = sourceIndex

                    var hidden = settings.sidebarHiddenTabs
                    hidden.removeAll { $0 == draggedTab }
                    settings.sidebarHiddenTabs = hidden

                    var visible = settings.sidebarVisibleTabs
                    let insertionIndex = min(max(index, 0), visible.count)
                    visible.insert(draggedTab, at: insertionIndex)
                    settings.sidebarVisibleTabs = visible
                    lastVisiblePosition[draggedTab] = insertionIndex
                } else {
                    let sourceIndex = settings.sidebarVisibleTabs.firstIndex(of: draggedTab) ?? 0
                    lastVisiblePosition[draggedTab] = sourceIndex

                    var visible = settings.sidebarVisibleTabs
                    visible.removeAll { $0 == draggedTab }
                    settings.sidebarVisibleTabs = visible

                    var hidden = settings.sidebarHiddenTabs
                    let insertionIndex = min(max(index, 0), hidden.count)
                    hidden.insert(draggedTab, at: insertionIndex)
                    settings.sidebarHiddenTabs = hidden
                    lastHiddenPosition[draggedTab] = insertionIndex
                }
            } else {
                var array = targetIsHidden ? settings.sidebarHiddenTabs : settings.sidebarVisibleTabs
                guard let sourceIndex = array.firstIndex(of: draggedTab) else {
                    return
                }
                array.remove(at: sourceIndex)
                let insertionIndex: Int
                if sourceIndex < index {
                    insertionIndex = min(max(index - 1, 0), array.count)
                } else {
                    insertionIndex = min(max(index, 0), array.count)
                }
                array.insert(draggedTab, at: insertionIndex)

                if targetIsHidden {
                    settings.sidebarHiddenTabs = array
                    for (position, tab) in array.enumerated() {
                        lastHiddenPosition[tab] = position
                    }
                } else {
                    settings.sidebarVisibleTabs = array
                    for (position, tab) in array.enumerated() {
                        lastVisiblePosition[tab] = position
                    }
                }
            }
        }

        self.draggedTab = nil
    }

    private func handleZoneDrop(toHidden targetIsHidden: Bool) {
        guard let draggedTab else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            if targetIsHidden {
                guard settings.sidebarVisibleTabs.contains(draggedTab) else { return }
                let sourceIndex = settings.sidebarVisibleTabs.firstIndex(of: draggedTab) ?? 0
                lastVisiblePosition[draggedTab] = sourceIndex

                var visible = settings.sidebarVisibleTabs
                visible.removeAll { $0 == draggedTab }
                settings.sidebarVisibleTabs = visible
                settings.sidebarHiddenTabs.append(draggedTab)
            } else {
                guard settings.sidebarHiddenTabs.contains(draggedTab) else { return }
                let sourceIndex = settings.sidebarHiddenTabs.firstIndex(of: draggedTab) ?? 0
                lastHiddenPosition[draggedTab] = sourceIndex

                var hidden = settings.sidebarHiddenTabs
                hidden.removeAll { $0 == draggedTab }
                settings.sidebarHiddenTabs = hidden
                settings.sidebarVisibleTabs.append(draggedTab)
            }
        }

        self.draggedTab = nil
    }

    private func moveHidden(from source: IndexSet, to destination: Int) {
        guard isEditing else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            settings.sidebarHiddenTabs.move(fromOffsets: source, toOffset: destination)
            for (position, tab) in settings.sidebarHiddenTabs.enumerated() {
                lastHiddenPosition[tab] = position
            }
        }
    }

}
