import SwiftUI

struct SettingsView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @Environment(\.colorScheme) private var colorScheme
    
    private let presetFontSizes: [CGFloat] = [10, 11, 12, 13, 14, 15, 16, 18, 20, 24, 28, 36]

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
                            Text("Font Size")
                                .frame(width: 100, alignment: .leading)
                            
                            Picker("", selection: Bindable(workspaceStore).editorFontSize) {
                                ForEach(presetFontSizes, id: \.self) { size in
                                    Text("\(Int(size)) pt").tag(size)
                                }
                            }
                            .frame(width: 120)
                            
                            Spacer()
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
