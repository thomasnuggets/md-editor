import AppKit

class MarkdownSyntaxHighlighter {

    // MARK: - Public entry point

    func highlight(_ storage: NSTextStorage) {
        let text = storage.string
        guard !text.isEmpty else { return }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        storage.beginEditing()

        // 1. Reset to base style
        let basePara = NSMutableParagraphStyle()
        basePara.lineSpacing = 5
        basePara.paragraphSpacing = 6
        storage.setAttributes([
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: basePara
        ], range: fullRange)

        // 2. Track code block ranges to skip inline formatting
        var codeBlockRanges: [NSRange] = []

        // 3. Process line by line
        var offset = 0
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeBlockStart = 0

        for line in lines {
            let lineLen = (line as NSString).length
            let lineRange = NSRange(location: offset, length: lineLen)

            // Code fence
            if line.hasPrefix("```") {
                if inCodeBlock {
                    let blockRange = NSRange(location: codeBlockStart, length: offset + lineLen - codeBlockStart)
                    codeBlockRanges.append(blockRange)
                    storage.addAttributes([
                        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .backgroundColor: codeBlockBackground()
                    ], range: blockRange)
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                    codeBlockStart = offset
                }
                offset += lineLen + 1
                continue
            }

            if inCodeBlock {
                offset += lineLen + 1
                continue
            }

            // Headers
            if let level = headerLevel(line) {
                applyHeader(level, to: storage, line: line, lineRange: lineRange)
            }
            // Blockquote
            else if line.hasPrefix("> ") {
                applyBlockquote(to: storage, lineRange: lineRange)
            }
            // Horizontal rule
            else if isHorizontalRule(line) {
                storage.addAttribute(.foregroundColor, value: NSColor.separatorColor, range: lineRange)
            }
            // Unordered list
            else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                applyList(to: storage, lineRange: lineRange, prefixLen: 2)
            }
            // Ordered list
            else if let prefixLen = orderedListPrefixLen(line) {
                applyList(to: storage, lineRange: lineRange, prefixLen: prefixLen)
            }

            offset += lineLen + 1
        }

        // Handle unclosed code block
        if inCodeBlock && codeBlockStart < fullRange.upperBound {
            let blockRange = NSRange(location: codeBlockStart, length: fullRange.upperBound - codeBlockStart)
            codeBlockRanges.append(blockRange)
            storage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ], range: blockRange)
        }

        // 4. Apply inline styles (outside code blocks)
        applyInline(to: storage, text: text, excluding: codeBlockRanges)

        storage.endEditing()
    }

    // MARK: - Block-level helpers

    private func headerLevel(_ line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard level <= 6, line.count > level, line[line.index(line.startIndex, offsetBy: level)] == " " else { return nil }
        return level
    }

    private func applyHeader(_ level: Int, to storage: NSTextStorage, line: String, lineRange: NSRange) {
        let fontSizes: [CGFloat] = [30, 24, 20, 18, 16, 15]
        let weights: [NSFont.Weight] = [.bold, .bold, .semibold, .semibold, .semibold, .medium]
        let topSpacings: [CGFloat] = [32, 24, 20, 16, 12, 10]
        let bottomSpacings: [CGFloat] = [8, 6, 4, 4, 2, 2]

        let prefixLen = level + 1 // "# " = level + 1 chars
        let fontSize = fontSizes[level - 1]
        let weight = weights[level - 1]

        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = topSpacings[level - 1]
        para.paragraphSpacing = bottomSpacings[level - 1]
        storage.addAttribute(.paragraphStyle, value: para, range: lineRange)

        // Style the # markers
        let markerLen = min(prefixLen, lineRange.length)
        let markerRange = NSRange(location: lineRange.location, length: markerLen)
        storage.addAttributes([
            .foregroundColor: NSColor.tertiaryLabelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        ], range: markerRange)

        // Style the heading text
        if lineRange.length > prefixLen {
            let textRange = NSRange(location: lineRange.location + prefixLen, length: lineRange.length - prefixLen)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize, weight: weight), range: textRange)
        }
    }

    private func applyBlockquote(to storage: NSTextStorage, lineRange: NSRange) {
        let para = NSMutableParagraphStyle()
        para.headIndent = 20
        para.firstLineHeadIndent = 0
        para.lineSpacing = 4
        storage.addAttributes([
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: para
        ], range: lineRange)
        if lineRange.length >= 2 {
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                 range: NSRange(location: lineRange.location, length: 2))
        }
    }

    private func applyList(to storage: NSTextStorage, lineRange: NSRange, prefixLen: Int) {
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = 0
        para.headIndent = 18
        para.lineSpacing = 4
        storage.addAttribute(.paragraphStyle, value: para, range: lineRange)
        let markerLen = min(prefixLen, lineRange.length)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                             range: NSRange(location: lineRange.location, length: markerLen))
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let s = line.replacingOccurrences(of: " ", with: "")
        return s == "---" || s == "***" || s == "___"
    }

    private func orderedListPrefixLen(_ line: String) -> Int? {
        guard let range = line.range(of: #"^\d+\.\s"#, options: .regularExpression) else { return nil }
        return line.distance(from: line.startIndex, to: range.upperBound)
    }

    // MARK: - Inline formatting

    private func applyInline(to storage: NSTextStorage, text: String, excluding codeBlocks: [NSRange]) {
        let nsText = text as NSString

        // Inline code (process first — its content stays monospace)
        applyPattern(#"`([^`\n]+)`"#, in: nsText, excluding: codeBlocks) { range in
            storage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.systemRed.blended(withFraction: 0.2, of: NSColor.labelColor) ?? NSColor.systemRed,
                .backgroundColor: self.inlineCodeBackground()
            ], range: range)
        }

        // Collect inline code ranges to skip them for bold/italic
        var inlineCodeRanges: [NSRange] = []
        applyPattern(#"`([^`\n]+)`"#, in: nsText, excluding: codeBlocks) { range in
            inlineCodeRanges.append(range)
        }
        let skipRanges = codeBlocks + inlineCodeRanges

        // Bold + Italic
        applyPattern(#"\*\*\*([^*\n]+?)\*\*\*"#, in: nsText, excluding: skipRanges) { range in
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .bold).addingTraits(.italic), range: range)
        }

        // Bold
        applyPattern(#"\*\*([^*\n]+?)\*\*"#, in: nsText, excluding: skipRanges) { range in
            let existing = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            let size = existing?.pointSize ?? 16
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .bold), range: range)
        }

        // Italic
        applyPattern(#"(?<!\*)\*([^*\n]+?)\*(?!\*)"#, in: nsText, excluding: skipRanges) { range in
            let existing = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            let size = existing?.pointSize ?? 16
            storage.addAttribute(.font, value: (existing ?? NSFont.systemFont(ofSize: size)).addingTraits(.italic), range: range)
        }

        // Strikethrough
        applyPattern(#"~~([^\n]+?)~~"#, in: nsText, excluding: skipRanges) { range in
            storage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor
            ], range: range)
        }

        // Links [text](url) — just color them
        applyPattern(#"\[([^\]]+)\]\([^)]+\)"#, in: nsText, excluding: skipRanges) { range in
            storage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
        }
    }

    // MARK: - Pattern helpers

    private func applyPattern(_ pattern: String, in nsText: NSString, excluding excluded: [NSRange], apply: (NSRange) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(location: 0, length: nsText.length)
        regex.enumerateMatches(in: nsText as String, range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            if !excluded.contains(where: { NSIntersectionRange($0, range).length > 0 }) {
                apply(range)
            }
        }
    }

    // MARK: - Color helpers

    private func codeBlockBackground() -> NSColor {
        if NSApp.effectiveAppearance.name == .darkAqua {
            return NSColor(white: 1, alpha: 0.05)
        }
        return NSColor(white: 0, alpha: 0.04)
    }

    private func inlineCodeBackground() -> NSColor {
        if NSApp.effectiveAppearance.name == .darkAqua {
            return NSColor(white: 1, alpha: 0.08)
        }
        return NSColor(white: 0, alpha: 0.06)
    }
}

// MARK: - NSFont extension

extension NSFont {
    func addingTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        var existing = fontDescriptor.symbolicTraits
        existing.insert(traits)
        let descriptor = fontDescriptor.withSymbolicTraits(existing)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
