import Foundation

class MarkdownParser {

    func parse(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var result = ""
        var i = 0
        var inCodeBlock = false
        var codeLanguage = ""
        var codeLines: [String] = []
        var inUnorderedList = false
        var inOrderedList = false
        var currentParagraph = ""

        func flushParagraph() {
            if !currentParagraph.isEmpty {
                result += "<p>\(parseInline(currentParagraph))</p>\n"
                currentParagraph = ""
            }
        }

        func closeLists() {
            if inUnorderedList { result += "</ul>\n"; inUnorderedList = false }
            if inOrderedList { result += "</ol>\n"; inOrderedList = false }
        }

        while i < lines.count {
            let line = lines[i]

            // Code block fence
            if line.hasPrefix("```") {
                if inCodeBlock {
                    let escaped = codeLines.joined(separator: "\n").htmlEscaped
                    let langAttr = codeLanguage.isEmpty ? "" : " class=\"language-\(codeLanguage)\""
                    result += "<pre><code\(langAttr)>\(escaped)</code></pre>\n"
                    inCodeBlock = false
                    codeLanguage = ""
                    codeLines = []
                } else {
                    flushParagraph()
                    closeLists()
                    inCodeBlock = true
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                i += 1
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                i += 1
                continue
            }

            // Empty line
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                closeLists()
                i += 1
                continue
            }

            // Headers
            if let (level, text) = matchHeader(line) {
                flushParagraph()
                closeLists()
                result += "<h\(level)>\(parseInline(text))</h\(level)>\n"
                i += 1
                continue
            }

            // Horizontal rule
            if isHorizontalRule(trimmed) {
                flushParagraph()
                closeLists()
                result += "<hr>\n"
                i += 1
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") {
                flushParagraph()
                closeLists()
                var quoteLines = [String(line.dropFirst(2))]
                while i + 1 < lines.count && lines[i + 1].hasPrefix("> ") {
                    i += 1
                    quoteLines.append(String(lines[i].dropFirst(2)))
                }
                let inner = parse(quoteLines.joined(separator: "\n"))
                result += "<blockquote>\(inner)</blockquote>\n"
                i += 1
                continue
            }

            // Unordered list
            if let listText = unorderedListItem(line) {
                flushParagraph()
                if !inUnorderedList {
                    if inOrderedList { result += "</ol>\n"; inOrderedList = false }
                    result += "<ul>\n"
                    inUnorderedList = true
                }
                if listText.hasPrefix("[ ] ") {
                    let content = parseInline(String(listText.dropFirst(4)))
                    result += "<li><input type=\"checkbox\" disabled> \(content)</li>\n"
                } else if listText.hasPrefix("[x] ") || listText.hasPrefix("[X] ") {
                    let content = parseInline(String(listText.dropFirst(4)))
                    result += "<li><input type=\"checkbox\" checked disabled> \(content)</li>\n"
                } else {
                    result += "<li>\(parseInline(listText))</li>\n"
                }
                i += 1
                continue
            }

            // Ordered list
            if let listText = orderedListItem(line) {
                flushParagraph()
                if !inOrderedList {
                    if inUnorderedList { result += "</ul>\n"; inUnorderedList = false }
                    result += "<ol>\n"
                    inOrderedList = true
                }
                result += "<li>\(parseInline(listText))</li>\n"
                i += 1
                continue
            }

            // Regular paragraph text
            closeLists()
            if currentParagraph.isEmpty {
                currentParagraph = line
            } else if currentParagraph.hasSuffix("  ") {
                currentParagraph = currentParagraph.trimmingCharacters(in: .init(charactersIn: " ")) + "<br>\n" + line
            } else {
                currentParagraph += " " + line
            }

            i += 1
        }

        flushParagraph()
        closeLists()
        if inCodeBlock {
            result += "<pre><code>\(codeLines.joined(separator: "\n").htmlEscaped)</code></pre>\n"
        }

        return result
    }

    // MARK: - Block helpers

    private func matchHeader(_ line: String) -> (Int, String)? {
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level) + " "
            if line.hasPrefix(prefix) {
                return (level, String(line.dropFirst(prefix.count)))
            }
        }
        return nil
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let s = line.replacingOccurrences(of: " ", with: "")
        return s == "---" || s == "***" || s == "___"
    }

    private func unorderedListItem(_ line: String) -> String? {
        if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
        if line.hasPrefix("* ") { return String(line.dropFirst(2)) }
        if line.hasPrefix("+ ") { return String(line.dropFirst(2)) }
        return nil
    }

    private func orderedListItem(_ line: String) -> String? {
        guard let range = line.range(of: #"^\d+\.\s"#, options: .regularExpression) else { return nil }
        return String(line[range.upperBound...])
    }

    // MARK: - Inline parsing

    func parseInline(_ text: String) -> String {
        var result = text

        // Images before links
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#,
            with: "<img src=\"$2\" alt=\"$1\">",
            options: .regularExpression
        )
        // Links
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )
        // Bold+Italic
        result = result.replacingOccurrences(of: #"\*\*\*(.+?)\*\*\*"#, with: "<strong><em>$1</em></strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"___(.+?)___"#, with: "<strong><em>$1</em></strong>", options: .regularExpression)
        // Bold
        result = result.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"__(.+?)__"#, with: "<strong>$1</strong>", options: .regularExpression)
        // Italic
        result = result.replacingOccurrences(of: #"\*([^*\n]+?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_([^_\n]+?)_"#, with: "<em>$1</em>", options: .regularExpression)
        // Strikethrough
        result = result.replacingOccurrences(of: #"~~(.+?)~~"#, with: "<del>$1</del>", options: .regularExpression)
        // Inline code
        result = result.replacingOccurrences(of: #"`([^`\n]+)`"#, with: "<code>$1</code>", options: .regularExpression)

        return result
    }

    // MARK: - HTML Template

    func fullHTML(for markdown: String) -> String {
        let body = parse(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
            --text: #1d1d1f;
            --secondary: #6e6e73;
            --code-bg: #f0f0f0;
            --border: #d1d1d6;
            --link: #007aff;
            --quote-border: #c7c7cc;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --text: #f5f5f7;
                --secondary: #98989d;
                --code-bg: #2d2d2d;
                --border: #3a3a3c;
                --quote-border: #48484a;
            }
        }
        body {
            font-family: -apple-system, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
            font-size: 16px;
            line-height: 1.75;
            color: var(--text);
            background: transparent;
            max-width: 700px;
            margin: 0 auto;
            padding: 32px 24px 120px;
            word-wrap: break-word;
        }
        h1, h2, h3, h4, h5, h6 {
            font-family: -apple-system, "SF Pro Display", sans-serif;
            font-weight: 700;
            line-height: 1.3;
            margin-top: 28px;
            margin-bottom: 10px;
            color: var(--text);
        }
        h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
        h1 { font-size: 2em; }
        h2 { font-size: 1.5em; font-weight: 600; }
        h3 { font-size: 1.25em; font-weight: 600; }
        h4, h5, h6 { font-size: 1em; font-weight: 600; }
        p { margin-bottom: 14px; }
        ul, ol { padding-left: 24px; margin-bottom: 14px; }
        li { margin-bottom: 4px; }
        strong { font-weight: 600; }
        em { font-style: italic; }
        del { text-decoration: line-through; color: var(--secondary); }
        code {
            font-family: "SF Mono", Menlo, Monaco, "Courier New", monospace;
            font-size: 0.875em;
            background: var(--code-bg);
            padding: 2px 6px;
            border-radius: 5px;
        }
        pre {
            background: var(--code-bg);
            border-radius: 10px;
            padding: 16px 20px;
            overflow-x: auto;
            margin-bottom: 16px;
        }
        pre code { background: none; padding: 0; font-size: 14px; line-height: 1.6; }
        blockquote {
            border-left: 3px solid var(--quote-border);
            margin: 16px 0;
            padding: 6px 16px;
            color: var(--secondary);
        }
        blockquote p { margin-bottom: 0; }
        a { color: var(--link); text-decoration: none; }
        a:hover { text-decoration: underline; }
        hr { border: none; border-top: 1px solid var(--border); margin: 24px 0; }
        img { max-width: 100%; border-radius: 8px; margin-bottom: 16px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 16px; }
        th, td { border: 1px solid var(--border); padding: 8px 12px; text-align: left; }
        th { background: var(--code-bg); font-weight: 600; }
        input[type="checkbox"] { margin-right: 6px; cursor: default; }
        li:has(> input[type="checkbox"]) { list-style: none; margin-left: -16px; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
