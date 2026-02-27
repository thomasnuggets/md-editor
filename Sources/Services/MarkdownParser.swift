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
                    let codeContent = codeLines.joined(separator: "\n")
                    let highlightedCode = highlightCode(codeContent, language: codeLanguage)
                    let langLabel = codeLanguage.isEmpty ? "" : "<div class=\"code-language\">\(codeLanguage)</div>"
                    result += "\(langLabel)<pre><code>\(highlightedCode)</code></pre>\n"
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
            let codeContent = codeLines.joined(separator: "\n")
            let highlightedCode = highlightCode(codeContent, language: codeLanguage)
            let langLabel = codeLanguage.isEmpty ? "" : "<div class=\"code-language\">\(codeLanguage)</div>"
            result += "\(langLabel)<pre><code>\(highlightedCode)</code></pre>\n"
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

    // MARK: - Syntax Highlighting

    func highlightCode(_ code: String, language: String) -> String {
        var highlighted = code.htmlEscaped
        
        // Common keywords for multiple languages
        let keywords = [
            "swift": ["import", "let", "var", "func", "class", "struct", "enum", "if", "else", "guard", "return", "switch", "case", "default", "break", "continue", "for", "while", "in", "self", "init", "deinit", "extension", "protocol", "associatedtype", "typealias", "where", "throws", "rethrows", "try", "catch", "throw", "async", "await", "actor", "convenience", "dynamic", "final", "lazy", "mutating", "nonmutating", "optional", "override", "required", "static", "unowned", "weak"],
            "javascript": ["const", "let", "var", "function", "class", "if", "else", "return", "for", "while", "switch", "case", "break", "continue", "try", "catch", "throw", "async", "await", "import", "export", "from", "default", "new", "this", "typeof", "instanceof"],
            "typescript": ["const", "let", "var", "function", "class", "interface", "type", "enum", "if", "else", "return", "for", "while", "switch", "case", "break", "continue", "try", "catch", "throw", "async", "await", "import", "export", "from", "default", "new", "this", "typeof", "instanceof", "readonly", "private", "protected", "public", "abstract", "implements", "extends", "namespace", "declare"],
            "python": ["import", "from", "def", "class", "if", "elif", "else", "for", "while", "try", "except", "finally", "with", "as", "return", "yield", "lambda", "pass", "break", "continue", "raise", "assert", "del", "global", "nonlocal", "and", "or", "not", "in", "is", "True", "False", "None"],
            "bash": ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "in", "function", "return", "exit", "echo", "export", "source", "alias", "unset", "local", "readonly", "shift", "break", "continue"],
            "sql": ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "INDEX", "VIEW", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT", "AS", "AND", "OR", "NOT", "NULL", "IS", "IN", "BETWEEN", "LIKE", "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END"]
        ]
        
        let lang = language.lowercased()
        let langKeywords = keywords[lang] ?? keywords["swift"]!
        
        // Highlight keywords
        for keyword in langKeywords {
            let pattern = "\\b\(keyword)\\b"
            highlighted = highlighted.replacingOccurrences(
                of: pattern,
                with: "<span class=\"keyword\">\(keyword)</span>",
                options: .regularExpression
            )
        }
        
        // Highlight strings (single and double quotes)
        highlighted = highlighted.replacingOccurrences(
            of: "(&quot;[^&quot;]*&quot;)",
            with: "<span class=\"string\">$1</span>",
            options: .regularExpression
        )
        highlighted = highlighted.replacingOccurrences(
            of: "(&#x27;[^&#x27;]*&#x27;)",
            with: "<span class=\"string\">$1</span>",
            options: .regularExpression
        )
        
        // Highlight numbers
        highlighted = highlighted.replacingOccurrences(
            of: "\\b(\\d+\\.?\\d*)\\b",
            with: "<span class=\"number\">$1</span>",
            options: .regularExpression
        )
        
        // Highlight comments (// and /* */)
        highlighted = highlighted.replacingOccurrences(
            of: "(//.*$)",
            with: "<span class=\"comment\">$1</span>",
            options: .regularExpression
        )
        
        // Highlight function calls
        highlighted = highlighted.replacingOccurrences(
            of: "(\\w+)(\\s*\\()",
            with: "<span class=\"function\">$1</span>$2",
            options: .regularExpression
        )
        
        return highlighted
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
            --text: #1a1a1a;
            --secondary: #6b7280;
            --code-bg: #f6f8fa;
            --code-inline-bg: #f3f4f6;
            --code-inline-text: #c2410c;
            --border: #e5e7eb;
            --link: #2563eb;
            --quote-border: #d1d5db;
            --quote-bg: #f9fafb;
            --heading: #111827;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --text: #f9fafb;
                --secondary: #9ca3af;
                --code-bg: #1f2937;
                --code-inline-bg: #374151;
                --code-inline-text: #fca5a5;
                --border: #374151;
                --quote-border: #4b5563;
                --quote-bg: #111827;
                --heading: #f9fafb;
            }
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            font-size: 16px;
            line-height: 1.8;
            color: var(--text);
            background: transparent;
            max-width: 720px;
            margin: 0 auto;
            padding: 40px 32px 120px;
            word-wrap: break-word;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }
        h1, h2, h3, h4, h5, h6 {
            font-family: Georgia, "Times New Roman", serif;
            font-weight: 700;
            line-height: 1.3;
            margin-top: 36px;
            margin-bottom: 16px;
            color: var(--heading);
            letter-spacing: -0.02em;
        }
        h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
        h1 { 
            font-size: 2.25em; 
            font-weight: 800;
            margin-bottom: 24px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border);
        }
        h2 { 
            font-size: 1.75em; 
            font-weight: 700;
            margin-top: 40px;
        }
        h3 { 
            font-size: 1.375em; 
            font-weight: 650;
            margin-top: 32px;
        }
        h4 { font-size: 1.125em; font-weight: 600; margin-top: 28px; }
        h5, h6 { font-size: 1em; font-weight: 600; margin-top: 24px; }
        p { 
            margin-bottom: 18px; 
            color: var(--text);
        }
        ul, ol { 
            padding-left: 28px; 
            margin-bottom: 18px;
        }
        li { 
            margin-bottom: 8px;
            line-height: 1.7;
        }
        ul li { list-style-type: disc; }
        ul li li { list-style-type: circle; }
        strong { 
            font-weight: 700; 
            color: var(--heading);
        }
        em { font-style: italic; }
        del { 
            text-decoration: line-through; 
            color: var(--secondary); 
        }
        code {
            font-family: "SF Mono", SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
            font-size: 0.875em;
            font-weight: 500;
            background: var(--code-inline-bg);
            color: var(--code-inline-text);
            padding: 3px 8px;
            border-radius: 6px;
            border: 1px solid var(--border);
        }
        pre {
            background: var(--code-bg);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 20px 24px;
            overflow-x: auto;
            margin-bottom: 24px;
            margin-top: 16px;
        }
        pre code { 
            background: none; 
            padding: 0; 
            font-size: 14px; 
            line-height: 1.7;
            color: inherit;
            border: none;
            font-weight: 400;
        }
        blockquote {
            border-left: 4px solid var(--quote-border);
            margin: 24px 0;
            padding: 16px 24px;
            background: var(--quote-bg);
            border-radius: 0 8px 8px 0;
            color: var(--secondary);
            font-style: italic;
        }
        blockquote p { 
            margin-bottom: 0; 
            color: var(--secondary);
        }
        blockquote p:last-child { margin-bottom: 0; }
        a { 
            color: var(--link); 
            text-decoration: none; 
            font-weight: 500;
            border-bottom: 1px solid transparent;
            transition: border-color 0.2s;
        }
        a:hover { 
            text-decoration: none; 
            border-bottom-color: var(--link);
        }
        hr { 
            border: none; 
            border-top: 1px solid var(--border); 
            margin: 40px 0; 
        }
        img { 
            max-width: 100%; 
            border-radius: 12px; 
            margin: 24px 0;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        table { 
            border-collapse: collapse; 
            width: 100%; 
            margin: 24px 0;
            border-radius: 8px;
            overflow: hidden;
        }
        th, td { 
            border: 1px solid var(--border); 
            padding: 12px 16px; 
            text-align: left; 
        }
        th { 
            background: var(--code-bg); 
            font-weight: 600;
            color: var(--heading);
        }
        tr:nth-child(even) { background: var(--quote-bg); }
        input[type="checkbox"] { 
            margin-right: 8px; 
            cursor: default;
            width: 16px;
            height: 16px;
            accent-color: var(--link);
        }
        li:has(> input[type="checkbox"]) { 
            list-style: none; 
            margin-left: -20px;
        }
        
        /* Code Language Label */
        .code-language {
            display: inline-block;
            font-family: "SF Mono", SFMono-Regular, Menlo, Monaco, monospace;
            font-size: 12px;
            font-weight: 500;
            color: var(--secondary);
            background: var(--code-bg);
            padding: 4px 12px;
            border-radius: 6px 6px 0 0;
            border: 1px solid var(--border);
            border-bottom: none;
            margin-bottom: -1px;
            margin-left: 16px;
            text-transform: lowercase;
        }
        
        /* Syntax Highlighting */
        .keyword { color: #d73a49; font-weight: 600; }
        .string { color: #032f62; }
        .comment { color: #6a737d; font-style: italic; }
        .number { color: #005cc5; }
        .function { color: #6f42c1; }
        .operator { color: #d73a49; }
        @media (prefers-color-scheme: dark) {
            .keyword { color: #ff7b72; }
            .string { color: #a5d6ff; }
            .comment { color: #8b949e; }
            .number { color: #79c0ff; }
            .function { color: #d2a8ff; }
            .operator { color: #ff7b72; }
        }
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
