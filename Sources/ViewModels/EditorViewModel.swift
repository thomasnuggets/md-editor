import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

// Shared coordinator to give toolbar access to the NSTextView
class TextViewCoordinator: ObservableObject {
    weak var textView: NSTextView?
    var lastKnownRange: NSRange = NSRange(location: 0, length: 0)

    func wrapSelection(prefix: String, suffix: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        if range.length > 0 {
            let selected = (tv.string as NSString).substring(with: range)
            tv.insertText(prefix + selected + suffix, replacementRange: range)
        } else {
            let saved = lastKnownRange
            tv.insertText(prefix + suffix, replacementRange: saved)
            tv.setSelectedRange(NSRange(location: saved.location + prefix.count, length: 0))
        }
        restoreFocus()
    }

    func insertAtLineStart(prefix: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        let nsStr = tv.string as NSString
        let lineRange = nsStr.lineRange(for: NSRange(location: range.location, length: 0))
        tv.insertText(prefix, replacementRange: NSRange(location: lineRange.location, length: 0))
        restoreFocus()
    }

    func insert(_ text: String) {
        guard let tv = textView else { return }
        tv.insertText(text, replacementRange: lastKnownRange)
        restoreFocus()
    }

    func restoreFocus() {
        textView?.window?.makeFirstResponder(textView)
    }
}

class EditorViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var isModified: Bool = false
    @Published var documentTitle: String = "Sans titre"
    @Published var currentFileURL: URL? = nil
    @Published var isSourceMode: Bool = false     // false = formatted (Typora-like), true = raw markdown
    @Published var showSidebar: Bool = false
    @Published var fileItems: [FileItem] = []
    @Published var currentFolderURL: URL? = nil

    let textViewCoordinator = TextViewCoordinator()
    private let parser = MarkdownParser()
    private let exportService = ExportService()
    private var autoSaveCancellable: AnyCancellable?

    init() {
        // Auto-save every 30s if modified and file exists
        autoSaveCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isModified, self.currentFileURL != nil else { return }
                self.saveFile()
            }
    }

    // MARK: - File Operations

    func newDocument() {
        guard confirmDiscardIfNeeded() else { return }
        content = ""
        currentFileURL = nil
        documentTitle = "Sans titre"
        isModified = false
    }

    func openFile() {
        guard confirmDiscardIfNeeded() else { return }

        let panel = NSOpenPanel()
        var types: [UTType] = [.plainText]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType(filenameExtension: "markdown") { types.append(markdown) }
        panel.allowedContentTypes = types
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFile(url: url)
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        currentFolderURL = url
        fileItems = loadFileItems(from: url)
        showSidebar = true
    }

    func loadFile(url: URL) {
        // Security-scoped access for sandboxed app
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            showAlert("Impossible de lire le fichier", info: "Vérifiez que le fichier est bien encodé en UTF-8.")
            return
        }

        content = text
        currentFileURL = url
        documentTitle = url.deletingPathExtension().lastPathComponent
        isModified = false
    }

    func saveFile() {
        if let url = currentFileURL {
            writeContent(to: url)
        } else {
            saveAs()
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        if let md = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [md]
        }
        panel.nameFieldStringValue = documentTitle + ".md"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        currentFileURL = url
        documentTitle = url.deletingPathExtension().lastPathComponent
        writeContent(to: url)
    }

    private func writeContent(to url: URL) {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            isModified = false
        } catch {
            showAlert("Erreur de sauvegarde", info: error.localizedDescription)
        }
    }

    func exportPDF() {
        let html = parser.fullHTML(for: content)
        exportService.exportPDF(html: html, suggestedName: documentTitle)
    }

    // MARK: - Editing Actions (toolbar)

    func applyBold() {
        textViewCoordinator.wrapSelection(prefix: "**", suffix: "**")
        markModified()
    }

    func applyItalic() {
        textViewCoordinator.wrapSelection(prefix: "*", suffix: "*")
        markModified()
    }

    func applyStrikethrough() {
        textViewCoordinator.wrapSelection(prefix: "~~", suffix: "~~")
        markModified()
    }

    func applyHeading(_ level: Int) {
        let prefix = String(repeating: "#", count: level) + " "
        textViewCoordinator.insertAtLineStart(prefix: prefix)
        markModified()
    }

    func insertLink() {
        textViewCoordinator.wrapSelection(prefix: "[", suffix: "](url)")
        markModified()
    }

    func insertBlockquote() {
        textViewCoordinator.insertAtLineStart(prefix: "> ")
        markModified()
    }

    func insertUnorderedList() {
        textViewCoordinator.insertAtLineStart(prefix: "- ")
        markModified()
    }

    func insertOrderedList() {
        textViewCoordinator.insertAtLineStart(prefix: "1. ")
        markModified()
    }

    func insertChecklist() {
        textViewCoordinator.insertAtLineStart(prefix: "- [ ] ")
        markModified()
    }

    func toggleSourceMode() {
        isSourceMode.toggle()
    }

    func markModified() {
        isModified = true
    }

    // MARK: - Sidebar

    private func loadFileItems(from url: URL) -> [FileItem] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let supported = Set(["md", "markdown", "mdown", "txt"])
        return contents
            .compactMap { itemURL -> FileItem? in
                let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if !isDir && !supported.contains(itemURL.pathExtension.lowercased()) { return nil }
                return FileItem(
                    url: itemURL,
                    name: itemURL.lastPathComponent,
                    isDirectory: isDir,
                    children: isDir ? loadFileItems(from: itemURL) : []
                )
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedCompare($1.name) == .orderedAscending
            }
    }

    // MARK: - Helpers

    private func confirmDiscardIfNeeded() -> Bool {
        guard isModified else { return true }
        let alert = NSAlert()
        alert.messageText = "Modifications non sauvegardées"
        alert.informativeText = "Voulez-vous continuer sans sauvegarder ?"
        alert.addButton(withTitle: "Continuer")
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showAlert(_ message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.runModal()
    }
}
