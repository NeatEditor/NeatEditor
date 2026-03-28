import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @State private var editorTextSoftnessJSON = ""
    @State private var editorTextSoftnessValidationMessage: String?

    var body: some View {
        @Bindable var bindableWorkspace = workspaceStore

        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Editor")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Tab Behavior")
                                .frame(width: 100, alignment: .leading)
                            
                            Picker("", selection: $bindableWorkspace.preferences.tabBehavior) {
                                ForEach(TabBehavior.allCases, id: \.self) { behavior in
                                    Text(LocalizedStringKey(behavior.rawValue)).tag(behavior)
                                }
                            }
                            .frame(width: 120)
                            
                            Spacer()
                        }
                        
                        HStack {
                            Text("Language")
                                .frame(width: 100, alignment: .leading)
                            
                            Picker("", selection: $bindableWorkspace.preferences.appLanguage) {
                                ForEach(AppLanguage.allCases, id: \.self) { language in
                                    Text(LocalizedStringKey(language.localizedNameKey)).tag(language)
                                }
                            }
                            .frame(width: 160)
                            
                            Spacer()
                        }
                        
                        if workspaceStore.isLanguageChangePendingRestart {
                            Text("A restart is required for language changes to take effect.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Editor Text Softness JSON")
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextEditor(text: $editorTextSoftnessJSON)
                                .font(.system(.body, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .frame(minHeight: 132)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(NSColor.textBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            editorTextSoftnessValidationMessage == nil
                                            ? EditorChrome.border
                                            : Color.orange,
                                            lineWidth: EditorChrome.lineWidth
                                        )
                                )
                                .onChange(of: editorTextSoftnessJSON) { _, newValue in
                                    applyEditorTextSoftnessJSON(newValue)
                                }

                            Text(
                                "支持的 key: lightModeTextSoftness、darkModeTextSoftness、highContrastTextSoftness。取值范围 0...1，合法 JSON 会立即生效。"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)

                            if let editorTextSoftnessValidationMessage {
                                Text(editorTextSoftnessValidationMessage)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(20)
                    .background(EditorChrome.editorSurface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(EditorChrome.border, lineWidth: EditorChrome.lineWidth)
                    )
                }
            }
            .padding(40)
            .frame(maxWidth: 800, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EditorChrome.editorSurface)
        .overlay {
            EditorSurfaceBorderShape()
                .stroke(EditorChrome.border, lineWidth: EditorChrome.lineWidth)
        }
        .onAppear {
            synchronizeEditorTextSoftnessJSON()
        }
        .onChange(of: workspaceStore.preferences.editorTextSoftness) { _, _ in
            synchronizeEditorTextSoftnessJSON()
        }
    }

    private func synchronizeEditorTextSoftnessJSON() {
        guard let jsonString = try? workspaceStore.preferences.editorTextSoftness.formattedJSONString() else {
            return
        }

        guard editorTextSoftnessJSON != jsonString else {
            if editorTextSoftnessValidationMessage == nil {
                return
            }

            editorTextSoftnessValidationMessage = nil
            return
        }

        editorTextSoftnessJSON = jsonString
        editorTextSoftnessValidationMessage = nil
    }

    private func applyEditorTextSoftnessJSON(_ jsonString: String) {
        do {
            let decodedConfiguration = try WorkspacePreferences.EditorTextSoftnessConfiguration
                .decodeValidating(jsonString: jsonString)
            editorTextSoftnessValidationMessage = nil

            guard workspaceStore.preferences.editorTextSoftness != decodedConfiguration else {
                return
            }

            workspaceStore.preferences.editorTextSoftness = decodedConfiguration
        } catch {
            editorTextSoftnessValidationMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .environment(WorkspaceStore())
        .frame(width: 600, height: 400)
}
