import SwiftUI

struct SettingsView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @Environment(\.colorScheme) private var colorScheme
    

    var body: some View {
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
                            
                            Picker("", selection: Bindable(workspaceStore).tabBehavior) {
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
                            
                            Picker("", selection: Bindable(workspaceStore).appLanguage) {
                                ForEach(AppLanguage.allCases, id: \.self) { language in
                                    Text(LocalizedStringKey(language.localizedName)).tag(language)
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
                    }
                    .padding(20)
                    .background(EditorChrome.editorSurface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(EditorChrome.border, lineWidth: 1)
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
                .stroke(EditorChrome.border, lineWidth: 1)
        }
    }
}

#Preview {
    SettingsView()
        .environment(WorkspaceStore())
        .frame(width: 600, height: 400)
}
