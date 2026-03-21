import SwiftUI

struct WorkspaceView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            @Bindable var bindableWorkspace = workspaceStore
            EditorTabStripView(
                tabs: $bindableWorkspace.tabs,
                selectedTabID: workspaceStore.selectedTabID,
                onSelectTab: workspaceStore.selectTab,
                onSelectTabRelative: workspaceStore.selectTab(relativeOffset:),
                onRenameTab: workspaceStore.renameDocument,
                onCloseTab: workspaceStore.closeDocument,
                onDeleteTab: workspaceStore.moveToTrash,
                onCloseOtherTabs: workspaceStore.closeOtherDocuments(keeping:)
            )

            if let selectedTabID = workspaceStore.selectedTabID,
               let index = workspaceStore.tabs.firstIndex(where: { $0.id == selectedTabID }) {
                let tab = workspaceStore.tabs[index]
                if tab.isSettings {
                    SettingsView()
                } else {
                    EditorTextView(
                        text: $bindableWorkspace.tabs[index].content,
                        fontSize: workspaceStore.editorFontSize,
                        tabBehavior: workspaceStore.tabBehavior,
                        searchQuery: workspaceStore.searchQuery,
                        isRegexSearchEnabled: workspaceStore.isRegexSearchEnabled,
                        searchRequestID: workspaceStore.searchRequestID,
                        onTextChange: { isComposing in
                            if isComposing {
                                workspaceStore.cancelAutoSave(for: selectedTabID)
                            } else {
                                workspaceStore.queueAutoSave(for: selectedTabID)
                            }
                        },
                        onCompositionEnd: {
                            workspaceStore.queueAutoSave(for: selectedTabID)
                        },
                        onIncreaseFontSize: {
                            workspaceStore.increaseEditorFontSize()
                        },
                        onDecreaseFontSize: {
                            workspaceStore.decreaseEditorFontSize()
                        },
                        onOpenFiles: { urls in
                            workspaceStore.openFiles(at: urls)
                        }
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .background(EditorChrome.editorSurface)
                        .overlay {
                            EditorSurfaceBorderShape()
                                .stroke(EditorChrome.border, lineWidth: 1)
                        }
                }
            } else {
                Text("No Document Selected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EditorChrome.editorSurface)
                    .overlay {
                        EditorSurfaceBorderShape()
                            .stroke(EditorChrome.border, lineWidth: 1)
                    }
            }

            if workspaceStore.isSearchBarPresented {
                searchBar
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .inactive || newPhase == .background {
                workspaceStore.saveAllDocuments()
            }
        }
        .onChange(of: workspaceStore.searchFocusRequestID) { _, _ in
            isSearchFieldFocused = workspaceStore.isSearchBarPresented
        }
        .dropDestination(for: URL.self) { items, _ in
            Task { @MainActor in
                workspaceStore.openFiles(at: items)
            }

            return true
        }
    }

    private var searchBar: some View {
        @Bindable var bindableWorkspace = workspaceStore

        return HStack(spacing: 12) {
            TextField("Search", text: $bindableWorkspace.searchQuery)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                .focusEffectDisabled()
                .focused($isSearchFieldFocused)
                .onSubmit {
                    workspaceStore.submitSearch()
                }

            Button {
                workspaceStore.toggleRegexSearch()
            } label: {
                Text(".*")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(
                        workspaceStore.isRegexSearchEnabled ? Color.accentColor : .secondary
                    )
                    .frame(minWidth: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(
                workspaceStore.isRegexSearchEnabled
                ? "Disable Regular Expression Search"
                : "Enable Regular Expression Search"
            )

            Button("Search") {
                workspaceStore.submitSearch()
            }
            .disabled(isSearchActionDisabled)

            Button {
                workspaceStore.dismissSearchBar()
                isSearchFieldFocused = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(.tertiary.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Search")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(EditorChrome.tabBarBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(EditorChrome.border)
                .frame(height: 1)
        }
    }

    private var isSearchActionDisabled: Bool {
        workspaceStore.selectedTabID == nil ||
        workspaceStore.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    WorkspaceView()
        .environment(WorkspaceStore())
        .frame(width: 800, height: 600)
}
