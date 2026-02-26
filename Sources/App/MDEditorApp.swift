import SwiftUI

@main
struct MDEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouveau document") {
                    viewModel.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Ouvrir un fichier…") {
                    viewModel.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Ouvrir un dossier…") {
                    viewModel.openFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Sauvegarder") {
                    viewModel.saveFile()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Sauvegarder sous…") {
                    viewModel.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Exporter en PDF…") {
                    viewModel.exportPDF()
                }
            }

            CommandMenu("Format") {
                Button("Gras") {
                    viewModel.applyBold()
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italique") {
                    viewModel.applyItalic()
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Barré") {
                    viewModel.applyStrikethrough()
                }

                Divider()

                Button("Titre H1") { viewModel.applyHeading(1) }
                Button("Titre H2") { viewModel.applyHeading(2) }
                Button("Titre H3") { viewModel.applyHeading(3) }

                Divider()

                Button("Liste à puces") { viewModel.insertUnorderedList() }
                Button("Liste numérotée") { viewModel.insertOrderedList() }
                Button("Liste de tâches") { viewModel.insertChecklist() }

                Divider()

                Button("Lien") { viewModel.insertLink() }
                Button("Citation") { viewModel.insertBlockquote() }
            }

            CommandMenu("Affichage") {
                Button(viewModel.isSourceMode ? "Vue formatée" : "Vue source (Markdown brut)") {
                    viewModel.toggleSourceMode()
                }
                .keyboardShortcut("\\", modifiers: .command)

                Button(viewModel.showSidebar ? "Masquer le panneau" : "Afficher le panneau") {
                    withAnimation { viewModel.showSidebar.toggle() }
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}
