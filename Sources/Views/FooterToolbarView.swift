import SwiftUI

struct FooterToolbarView: View {
    @EnvironmentObject var vm: EditorViewModel

    var body: some View {
        HStack(spacing: 2) {
            // Formatting buttons
            ToolbarButton(label: "B", font: .system(size: 14, weight: .bold), tooltip: "Gras (⌘B)") {
                vm.applyBold()
            }
            ToolbarButton(label: "I", font: .system(size: 14, weight: .regular).italic(), tooltip: "Italique (⌘I)") {
                vm.applyItalic()
            }
            ToolbarButton(label: "S", font: .system(size: 14, weight: .regular), tooltip: "Barré", strikethrough: true) {
                vm.applyStrikethrough()
            }

            ToolbarDivider()

            // Heading dropdown
            Menu {
                Button("Titre H1") { vm.applyHeading(1) }
                Button("Titre H2") { vm.applyHeading(2) }
                Button("Titre H3") { vm.applyHeading(3) }
            } label: {
                HStack(spacing: 3) {
                    Text("Aa")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            ToolbarDivider()

            ToolbarIconButton(icon: "list.bullet", tooltip: "Liste à puces") { vm.insertUnorderedList() }
            ToolbarIconButton(icon: "list.number", tooltip: "Liste numérotée") { vm.insertOrderedList() }
            ToolbarIconButton(icon: "checklist", tooltip: "Liste de tâches") { vm.insertChecklist() }

            ToolbarDivider()

            ToolbarIconButton(icon: "link", tooltip: "Lien") { vm.insertLink() }
            ToolbarIconButton(icon: "text.quote", tooltip: "Citation") { vm.insertBlockquote() }

            ToolbarDivider()

            // Toggle source / formatted
            Button(action: { vm.toggleSourceMode() }) {
                HStack(spacing: 4) {
                    Image(systemName: vm.isSourceMode ? "eye" : "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 11, weight: .medium))
                    Text(vm.isSourceMode ? "Formatté" : "Source")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(vm.isSourceMode ? Color.accentColor : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((vm.isSourceMode ? Color.accentColor : Color.primary).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 4)
    }
}

// MARK: - Sub-components

struct ToolbarButton: View {
    let label: String
    var font: Font = .system(size: 14)
    var tooltip: String = ""
    var strikethrough: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .strikethrough(strikethrough)
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}

struct ToolbarIconButton: View {
    let icon: String
    var tooltip: String = ""
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 4)
    }
}
