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
                        fontSize: workspaceStore.preferences.editorFontSize,
                        tabBehavior: workspaceStore.preferences.tabBehavior,
                        textSoftness: workspaceStore.preferences.editorTextSoftness,
                        searchState: workspaceStore.searchState,
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
                                .stroke(EditorChrome.border, lineWidth: EditorChrome.lineWidth)
                        }
                }
            } else {
                Text("No Document Selected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EditorChrome.editorSurface)
                    .overlay {
                        EditorSurfaceBorderShape()
                            .stroke(EditorChrome.border, lineWidth: EditorChrome.lineWidth)
                    }
            }

            if workspaceStore.searchState.isPresented {
                searchBar
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .alert(
            workspaceStore.renameFailureAlert?.title ?? "Rename Failed",
            isPresented: renameFailureAlertIsPresented,
            presenting: workspaceStore.renameFailureAlert
        ) { _ in
            Button("OK", role: .cancel) {
                workspaceStore.dismissRenameFailureAlert()
            }
        } message: { alert in
            Text(alert.message)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .inactive || newPhase == .background {
                workspaceStore.saveAllDocuments()
            }
        }
        .onChange(of: workspaceStore.searchState.focusRequestID) { _, _ in
            isSearchFieldFocused = workspaceStore.searchState.isPresented
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
            TextField("Search", text: $bindableWorkspace.searchState.query)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(EditorChrome.border, lineWidth: EditorChrome.lineWidth)
                )
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
                        workspaceStore.searchState.isRegexEnabled ? Color.accentColor : .secondary
                    )
                    .frame(minWidth: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(
                workspaceStore.searchState.isRegexEnabled
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
                .frame(height: EditorChrome.lineWidth)
        }
    }

    private var isSearchActionDisabled: Bool {
        workspaceStore.selectedTabID == nil ||
        !workspaceStore.searchState.canSubmit
    }

    private var renameFailureAlertIsPresented: Binding<Bool> {
        Binding(
            get: { workspaceStore.renameFailureAlert != nil },
            set: { isPresented in
                if !isPresented {
                    workspaceStore.dismissRenameFailureAlert()
                }
            }
        )
    }
}

#Preview {
    WorkspaceView()
        .environment(WorkspaceStore())
        .frame(width: 800, height: 600)
}
