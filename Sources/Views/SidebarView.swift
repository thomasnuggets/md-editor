import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var vm: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let folder = vm.currentFolderURL {
                    Label(folder.lastPathComponent, systemImage: "folder.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text("Fichiers")
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.showSidebar = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // File tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(vm.fileItems) { item in
                        FileItemRow(item: item, depth: 0)
                            .environmentObject(vm)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 4)
    }
}

struct FileItemRow: View {
    @ObservedObject var item: FileItem
    let depth: Int
    @EnvironmentObject var vm: EditorViewModel
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // Indent
                if depth > 0 {
                    Spacer().frame(width: CGFloat(depth) * 16)
                }

                if item.isDirectory {
                    Image(systemName: item.isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0, green: 0.478, blue: 1))
                        .frame(width: 16)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }

                Text(item.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if item.isDirectory {
                    Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 6)
            .onHover { isHovered = $0 }
            .onTapGesture {
                if item.isDirectory {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        item.isExpanded.toggle()
                    }
                } else {
                    vm.loadFile(url: item.url)
                }
            }

            // Children
            if item.isDirectory && item.isExpanded {
                ForEach(item.children) { child in
                    FileItemRow(item: child, depth: depth + 1)
                        .environmentObject(vm)
                }
            }
        }
    }
}
