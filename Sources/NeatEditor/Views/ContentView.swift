import SwiftUI

struct ContentView: View {
    @Environment(DocumentManager.self) private var documentManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            @Bindable var docMgr = documentManager
            TabBarView(tabs: $docMgr.tabs, selectedTabID: $docMgr.selectedTabID)

            if let selectedTabID = documentManager.selectedTabID,
               let index = documentManager.tabs.firstIndex(where: { $0.id == selectedTabID }) {
                TextEditor(text: Bindable(documentManager).tabs[index].content)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(EditorChrome.editorSurface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: documentManager.tabs[index].content) { _, _ in
                        documentManager.queueAutoSave(for: selectedTabID)
                    }
                    .background(EditorChrome.editorSurface)
                    .overlay {
                        EditorSurfaceBorderShape()
                            .stroke(EditorChrome.border, lineWidth: 1)
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
        }
        .ignoresSafeArea(.all, edges: .top)
        .onChange(of: documentManager.selectedTabID) { oldID, newID in
            if let oldID {
                documentManager.saveDocument(id: oldID)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .inactive || newPhase == .background {
                documentManager.saveAllDocuments()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(DocumentManager())
        .frame(width: 800, height: 600)
}
