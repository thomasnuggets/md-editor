import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: EditorViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag region for frameless window
                DragRegion().frame(height: 8)

                // Header
                HeaderView().environmentObject(vm)

                // Body — scrollable, content centré max 680px
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        ScrollView(.vertical, showsIndicators: true) {
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)
                                MarkdownTextEditor(
                                    text: $vm.content,
                                    showFormatting: !vm.isSourceMode,
                                    onTextChange: { _ in vm.markModified() },
                                    coordinator: vm.textViewCoordinator
                                )
                                .frame(width: min(680, geo.size.width - 48))
                                .frame(minHeight: geo.size.height - 80)
                                Spacer(minLength: 0)
                            }
                            .padding(.bottom, 80) // room for footer
                        }
                    }

                    // Sidebar overlay
                    if vm.showSidebar {
                        HStack(spacing: 0) {
                            SidebarView()
                                .environmentObject(vm)
                                .padding(.leading, 20)
                                .padding(.top, 12)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Spacer()
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: vm.showSidebar)
            }

            // Floating footer toolbar
            FooterToolbarView()
                .environmentObject(vm)
                .padding(.bottom, 16)
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            configureWindow()
            vm.content = welcomeText
        }
        .background(
            Group {
                Button("") { vm.newDocument() }.keyboardShortcut("n", modifiers: .command).hidden()
                Button("") { vm.openFile() }.keyboardShortcut("o", modifiers: .command).hidden()
                Button("") { vm.openFolder() }.keyboardShortcut("o", modifiers: [.command, .shift]).hidden()
                Button("") { vm.saveFile() }.keyboardShortcut("s", modifiers: .command).hidden()
                Button("") { vm.saveAs() }.keyboardShortcut("s", modifiers: [.command, .shift]).hidden()
                Button("") { vm.applyBold() }.keyboardShortcut("b", modifiers: .command).hidden()
                Button("") { vm.applyItalic() }.keyboardShortcut("i", modifiers: .command).hidden()
                Button("") { vm.toggleSourceMode() }.keyboardShortcut("\\", modifiers: .command).hidden()
            }
        )
    }

    private func configureWindow() {
        guard let window = NSApp.windows.first else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        if window.frame.size == .zero {
            window.setContentSize(NSSize(width: 920, height: 700))
            window.center()
        }
    }

    private var welcomeText: String {
        """
        # Bienvenue dans MD Editor

        Un éditeur Markdown minimaliste pour macOS.

        ## Pour commencer

        - Ouvrez un fichier `.md` avec le bouton **Ouvrir**
        - Créez un nouveau document avec **Nouveau**
        - Basculez entre vue formatée et source avec **⌘\\**

        ## Mise en forme

        Le texte supporte la **mise en gras**, *l'italique*, et le ~~barré~~.

        ### Listes

        1. Éléments numérotés
        2. Ou avec des puces

        - [x] Lancer MD Editor
        - [ ] Écrire quelque chose de génial

        ### Code

        ```swift
        let editor = "MD Editor"
        print("Bienvenue dans \\(editor) !")
        ```

        > *"La simplicité est la sophistication suprême."*
        > — Leonardo da Vinci
        """
    }
}

// MARK: - Drag region

struct DragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView { DraggableNSView() }
    func updateNSView(_ nsView: DraggableNSView, context: Context) {}
}

class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
