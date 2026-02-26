import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var vm: EditorViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Left actions
            HStack(spacing: 8) {
                HeaderButton(icon: "square.and.pencil", label: "Nouveau") {
                    vm.newDocument()
                }
                HeaderButton(icon: "folder", label: "Ouvrir") {
                    vm.openFile()
                }
                HeaderButton(icon: "folder.badge.plus", label: "Dossier") {
                    vm.openFolder()
                }
            }

            Spacer()

            // Center: title + modified indicator
            HStack(spacing: 6) {
                if vm.isModified {
                    Circle()
                        .fill(Color(red: 1, green: 0.584, blue: 0))
                        .frame(width: 8, height: 8)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(vm.documentTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .animation(.easeInOut(duration: 0.2), value: vm.isModified)

            Spacer()

            // Right actions
            HStack(spacing: 8) {
                HeaderButton(icon: "arrow.uturn.backward", label: "Annuler") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                HeaderButton(icon: "arrow.uturn.forward", label: "Rétablir") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                HeaderButton(icon: "square.and.arrow.down", label: "Sauvegarder", accent: vm.isModified) {
                    vm.saveFile()
                }
                HeaderButton(icon: "arrow.down.doc", label: "PDF") {
                    vm.exportPDF()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

struct HeaderButton: View {
    let icon: String
    var label: String = ""
    var accent: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(accent ? Color.accentColor : (isHovered ? .primary : .secondary))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
