import SwiftUI

struct TabBarView: View {
    @Binding var tabs: [TabItem]
    @Binding var selectedTabID: UUID?
    
    // Window control buttons width + padding to ensure tabs don't overlap traffic lights
    private let leadingPadding: CGFloat = 76
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach($tabs) { $tab in
                    TabItemView(tab: $tab, isSelected: selectedTabID == tab.id) {
                        selectedTabID = tab.id
                    }
                }
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, 16)
            .padding(.top, 6)
        }
        .background(EditorChrome.tabBarBackground)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(EditorChrome.border)
                .frame(height: 1)
        }
        .frame(height: 38)
    }
}

// Subview for a single Tab
struct TabItemView: View {
    @Binding var tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                tabBackground

                HStack(spacing: 6) {
                    if isEditing {
                        TextField("", text: $tab.title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                            .focused($isFocused)
                            .labelsHidden()
                            .onSubmit {
                                isEditing = false
                            }
                            .onChange(of: isFocused) { _, isFocusedValue in
                                if !isFocusedValue {
                                    isEditing = false
                                }
                            }
                            .frame(minWidth: 40)
                    } else {
                        Text(tab.title)
                            .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                            .foregroundColor(isSelected ? .primary : .secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .frame(minWidth: 68)
            .frame(height: 32, alignment: .bottom)
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 1 : 0)
        .onHover { hovering in
            isHovering = hovering
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            isEditing = true
            isFocused = true
        })
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            ConnectedTabFillShape(cornerRadius: 9)
                .fill(EditorChrome.editorSurface)
                .overlay {
                    ConnectedTabBorderShape(cornerRadius: 9)
                        .stroke(
                            EditorChrome.border,
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                        )
                }
        } else if isHovering {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(EditorChrome.hoverFill)
                .padding(.horizontal, 2)
                .padding(.top, 3)
                .padding(.bottom, 5)
        }
    }
}

private struct ConnectedTabFillShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        return path
    }
}

private struct ConnectedTabBorderShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        return path
    }
}

#Preview {
    @Previewable @State var tabs = [
        TabItem(id: UUID(), title: "Untitled 1"),
        TabItem(id: UUID(), title: "Config.yml"),
        TabItem(id: UUID(), title: "Readme.md")
    ]
    @Previewable @State var selectedTabID: UUID?
    
    VStack(spacing: 0) {
        TabBarView(tabs: $tabs, selectedTabID: $selectedTabID)
        Spacer()
    }
    .frame(width: 400, height: 200)
    .background(EditorChrome.tabBarBackground)
    .onAppear {
        selectedTabID = tabs.first?.id
    }
}
