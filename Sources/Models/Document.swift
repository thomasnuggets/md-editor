import Foundation

struct MarkdownDocument {
    var content: String
    var fileURL: URL?
    var title: String

    init(content: String = "", fileURL: URL? = nil) {
        self.content = content
        self.fileURL = fileURL
        self.title = fileURL?.deletingPathExtension().lastPathComponent ?? "Sans titre"
    }
}

class FileItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let children: [FileItem]
    @Published var isExpanded: Bool = false

    init(url: URL, name: String, isDirectory: Bool, children: [FileItem] = []) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.children = children
    }
}
