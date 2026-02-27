import AppKit

// MARK: - Main highlighter

class MarkdownSyntaxHighlighter {

    // MARK: - Theme

    private var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    // Fonts
    private var bodyFont:  NSFont { .systemFont(ofSize: 16, weight: .regular) }
    private var h1Font:    NSFont { .systemFont(ofSize: 28, weight: .bold) }
    private var h2Font:    NSFont { .systemFont(ofSize: 22, weight: .bold) }
    private var h3Font:    NSFont { .systemFont(ofSize: 18, weight: .semibold) }
    private var h4Font:    NSFont { .systemFont(ofSize: 16, weight: .semibold) }
    private var h5Font:    NSFont { .systemFont(ofSize: 15, weight: .semibold) }
    private var h6Font:    NSFont { .systemFont(ofSize: 14, weight: .semibold) }
    private var codeFont:  NSFont { .monospacedSystemFont(ofSize: 13.5, weight: .regular) }
    private var ghostFont: NSFont { .systemFont(ofSize: 0.01) }   // for hidden markers

    // Colors
    private var bodyColor: NSColor { .labelColor }
    private var dimColor:  NSColor { .secondaryLabelColor }
    private var faintColor: NSColor { .tertiaryLabelColor }

    private var inlineCodeFg: NSColor {
        isDark ? NSColor(red: 0.92, green: 0.52, blue: 0.56, alpha: 1.0)
               : NSColor(red: 0.68, green: 0.10, blue: 0.22, alpha: 1.0)
    }
    private var inlineCodeBg: NSColor {
        isDark ? NSColor(white: 1.0, alpha: 0.08)
               : NSColor(white: 0.0, alpha: 0.055)
    }
    private var codeBlockFg: NSColor {
        isDark ? NSColor(white: 0.82, alpha: 1.0)
               : NSColor(white: 0.18, alpha: 1.0)
    }
    private var codeBlockBg: NSColor {
        isDark ? NSColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
               : NSColor(red: 0.963, green: 0.968, blue: 0.978, alpha: 1.0)
    }
    private var blockquoteFg: NSColor {
        isDark ? NSColor(white: 0.65, alpha: 1.0)
               : NSColor(white: 0.38, alpha: 1.0)
    }
    private var blockquoteBg: NSColor {
        isDark ? NSColor(red: 0.42, green: 0.36, blue: 0.90, alpha: 0.13)
               : NSColor(red: 0.42, green: 0.36, blue: 0.90, alpha: 0.06)
    }
    private var linkColor: NSColor { .systemBlue }

    // MARK: - Base paragraph style

    private var basePara: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 5
        p.paragraphSpacing = 14
        return p
    }

    // MARK: - Entry point

    func highlight(_ storage: NSTextStorage) {
        let text = storage.string
        guard !text.isEmpty else { return }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        storage.beginEditing()
        defer { storage.endEditing() }

        // 1. Full reset to base
        storage.setAttributes([
            .font: bodyFont,
            .foregroundColor: bodyColor,
            .paragraphStyle: basePara
        ], range: fullRange)

        // 2. Block-level pass
        var codeBlockRanges: [NSRange] = []
        processBlocks(storage: storage, text: text, nsText: nsText, codeBlockRanges: &codeBlockRanges)

        // 3. Inline pass (outside code blocks)
        let icRanges = applyInlineCode(storage: storage, text: text, excluding: codeBlockRanges)
        let skip = codeBlockRanges + icRanges
        applyBoldItalic(storage: storage, text: text, excluding: skip)
        applyStrikethrough(storage: storage, text: text, excluding: skip)
        applyLinks(storage: storage, text: text, excluding: skip)
    }

    // MARK: - Block processor

    private func processBlocks(storage: NSTextStorage, text: String, nsText: NSString, codeBlockRanges: inout [NSRange]) {
        let lines = text.components(separatedBy: "\n")
        var offset = 0
        var inCodeBlock = false
        var codeBlockStart = 0

        for line in lines {
            let lineLen = (line as NSString).length
            let lineEnd = offset + lineLen
            let lr = NSRange(location: offset, length: lineLen)
            // Extended range includes the trailing newline (for paragraph-level styling)
            let maxEnd = nsText.length
            let lrExt = NSRange(location: offset, length: min(lineLen + 1, maxEnd - offset))

            defer { offset = min(lineEnd + 1, maxEnd) }

            // ── Code fence ──────────────────────────────────────────────────
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // Close: collect full block range, hide closing fence
                    let blockRange = NSRange(location: codeBlockStart, length: lineEnd - codeBlockStart)
                    codeBlockRanges.append(blockRange)
                    hide(lr, in: storage)
                    inCodeBlock = false
                } else {
                    // Open: hide opening fence
                    inCodeBlock = true
                    codeBlockStart = offset
                    hide(lr, in: storage)
                }
                continue
            }

            if inCodeBlock {
                applyCodeLine(lr, ext: lrExt, in: storage)
                codeBlockRanges.append(lr)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // ── Header ──────────────────────────────────────────────────────
            if let level = headerLevel(line) {
                applyHeader(level: level, line: line, lr: lr, ext: lrExt, in: storage)
            }
            // ── Blockquote ──────────────────────────────────────────────────
            else if line.hasPrefix("> ") || line == ">" {
                applyBlockquote(line: line, lr: lr, ext: lrExt, in: storage)
            }
            // ── Horizontal rule ─────────────────────────────────────────────
            else if isHR(trimmed) {
                applyHR(lr: lr, in: storage)
            }
            // ── Checklist (before unordered list) ───────────────────────────
            else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                applyChecklist(line: line, lr: lr, ext: lrExt, in: storage)
            }
            // ── Unordered list ──────────────────────────────────────────────
            else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                applyUList(lr: lr, ext: lrExt, in: storage)
            }
            // ── Ordered list ────────────────────────────────────────────────
            else if let pl = orderedPrefixLen(line) {
                applyOList(prefixLen: pl, lr: lr, ext: lrExt, in: storage)
            }
        }
    }

    // MARK: - Block stylers

    private func hide(_ range: NSRange, in storage: NSTextStorage) {
        guard range.length > 0, range.upperBound <= (storage.string as NSString).length else { return }
        storage.addAttributes([
            .foregroundColor: NSColor.clear,
            .font: ghostFont
        ], range: range)
    }

    private func applyHeader(level: Int, line: String, lr: NSRange, ext: NSRange, in storage: NSTextStorage) {
        let prefixLen = level + 1
        let fonts = [h1Font, h2Font, h3Font, h4Font, h5Font, h6Font]
        let topSpace: [CGFloat]    = [36, 28, 22, 18, 14, 12]
        let bottomSpace: [CGFloat] = [10,  8,  6,  4,  2,  2]

        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = topSpace[level - 1]
        para.paragraphSpacing       = bottomSpace[level - 1]
        para.lineSpacing = 2
        storage.addAttribute(.paragraphStyle, value: para, range: ext)

        // Hide the "# " markers
        let markerLen = min(prefixLen, lr.length)
        hide(NSRange(location: lr.location, length: markerLen), in: storage)

        // Apply heading font to content
        let contentLen = lr.length - markerLen
        if contentLen > 0 {
            let contentRange = NSRange(location: lr.location + markerLen, length: contentLen)
            storage.addAttribute(.font, value: fonts[level - 1], range: contentRange)
        }
    }

    private func applyCodeLine(_ lr: NSRange, ext: NSRange, in storage: NSTextStorage) {
        let para = NSMutableParagraphStyle()
        para.lineSpacing           = 2
        para.paragraphSpacing      = 0
        para.paragraphSpacingBefore = 0
        para.firstLineHeadIndent   = 16
        para.headIndent            = 16
        para.tailIndent            = -16

        storage.addAttributes([
            .font:            codeFont,
            .foregroundColor: codeBlockFg,
            .backgroundColor: codeBlockBg,
            .paragraphStyle:  para
        ], range: ext)
    }

    private func applyBlockquote(line: String, lr: NSRange, ext: NSRange, in storage: NSTextStorage) {
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = 16
        para.headIndent          = 16
        para.tailIndent          = -8
        para.lineSpacing         = 4
        para.paragraphSpacing    = 8

        storage.addAttributes([
            .foregroundColor: blockquoteFg,
            .backgroundColor: blockquoteBg,
            .paragraphStyle:  para
        ], range: ext)

        // Hide "> " prefix
        let prefixLen = min(2, lr.length)
        hide(NSRange(location: lr.location, length: prefixLen), in: storage)
    }

    private func applyHR(lr: NSRange, in storage: NSTextStorage) {
        // Make the --- look like a thin line by collapsing the text
        storage.addAttributes([
            .foregroundColor: NSColor.separatorColor,
            .font:            NSFont.systemFont(ofSize: 4),
            .backgroundColor: NSColor.separatorColor
        ], range: lr)
        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = 16
        para.paragraphSpacing       = 16
        storage.addAttribute(.paragraphStyle, value: para, range: lr)
    }

    private func applyUList(lr: NSRange, ext: NSRange, in storage: NSTextStorage) {
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = 0
        para.headIndent          = 20
        para.lineSpacing         = 4
        para.paragraphSpacing    = 5
        storage.addAttribute(.paragraphStyle, value: para, range: ext)

        // Dim the bullet character
        if lr.length >= 1 {
            storage.addAttribute(.foregroundColor, value: faintColor,
                                 range: NSRange(location: lr.location, length: 1))
        }
    }

    private func applyOList(prefixLen: Int, lr: NSRange, ext: NSRange, in storage: NSTextStorage) {
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = 0
        para.headIndent          = CGFloat(prefixLen) * 9 + 4
        para.lineSpacing         = 4
        para.paragraphSpacing    = 5
        storage.addAttribute(.paragraphStyle, value: para, range: ext)

        // Dim the "1. " prefix
        if lr.length >= prefixLen {
            storage.addAttribute(.foregroundColor, value: faintColor,
                                 range: NSRange(location: lr.location, length: prefixLen))
        }
    }

    private func applyChecklist(line: String, lr: NSRange, ext: NSRange, in storage: NSTextStorage) {
        let isChecked = line.hasPrefix("- [x]") || line.hasPrefix("- [X]")

        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = 0
        para.headIndent          = 22
        para.lineSpacing         = 4
        para.paragraphSpacing    = 5
        storage.addAttribute(.paragraphStyle, value: para, range: ext)

        // Hide "- " (first 2 chars)
        hide(NSRange(location: lr.location, length: min(2, lr.length)), in: storage)

        // Style the checkbox "[x]" or "[ ]"
        if lr.length >= 5 {
            let cbRange = NSRange(location: lr.location + 2, length: 3)
            storage.addAttributes([
                .font:            NSFont.monospacedSystemFont(ofSize: 14, weight: isChecked ? .medium : .regular),
                .foregroundColor: isChecked ? NSColor.systemGreen : faintColor
            ], range: cbRange)
        }

        // Strike-through checked content
        if isChecked && lr.length > 6 {
            let contentRange = NSRange(location: lr.location + 6, length: lr.length - 6)
            storage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor:    dimColor
            ], range: contentRange)
        }
    }

    // MARK: - Inline: code

    private func applyInlineCode(storage: NSTextStorage, text: String, excluding: [NSRange]) -> [NSRange] {
        var found: [NSRange] = []
        guard let regex = try? NSRegularExpression(pattern: #"`([^`\n]+)`"#) else { return found }

        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) { match, _, _ in
            guard let m = match else { return }
            guard !excluding.overlaps(m.range) else { return }
            guard let inner = m.range(at: 1).notFound else { return }
            found.append(m.range)

            // Hide backtick markers
            hide(NSRange(location: m.range.location, length: 1), in: storage)
            hide(NSRange(location: m.range.upperBound - 1, length: 1), in: storage)

            // Style content
            storage.addAttributes([
                .font:            codeFont,
                .foregroundColor: inlineCodeFg,
                .backgroundColor: inlineCodeBg
            ], range: inner)
        }
        return found
    }

    // MARK: - Inline: bold, italic

    private func applyBoldItalic(storage: NSTextStorage, text: String, excluding: [NSRange]) {
        // Bold+Italic ***text***
        eachMatchHideMarkers(#"\*\*\*([^*\n]+?)\*\*\*"#, in: text, storage: storage,
                             codeBlocks: excluding, markerLen: 3) { inner in
            let font = bodyFont.addingTraits(.italic).withBoldWeight()
            storage.addAttribute(.font, value: font, range: inner)
        }

        // Bold **text**
        eachMatchHideMarkers(#"\*\*([^*\n]+?)\*\*"#, in: text, storage: storage,
                             codeBlocks: excluding, markerLen: 2) { inner in
            let existing = storage.attribute(.font, at: inner.location, effectiveRange: nil) as? NSFont
            let size = existing?.pointSize ?? 16
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .bold), range: inner)
        }

        // Italic *text* (not inside **)
        eachMatchHideMarkers(#"(?<!\*)\*([^*\n]+?)\*(?!\*)"#, in: text, storage: storage,
                             codeBlocks: excluding, markerLen: 1) { inner in
            let existing = storage.attribute(.font, at: inner.location, effectiveRange: nil) as? NSFont
            storage.addAttribute(.font, value: (existing ?? bodyFont).addingTraits(.italic), range: inner)
        }
    }

    // MARK: - Inline: strikethrough

    private func applyStrikethrough(storage: NSTextStorage, text: String, excluding: [NSRange]) {
        eachMatchHideMarkers(#"~~([^\n]+?)~~"#, in: text, storage: storage,
                             codeBlocks: excluding, markerLen: 2) { inner in
            storage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor:    dimColor
            ], range: inner)
        }
    }

    // MARK: - Inline: links

    private func applyLinks(storage: NSTextStorage, text: String, excluding: [NSRange]) {
        // [label](url) → show label in blue, hide [, ](url)
        eachMatch(#"\[([^\]]+)\]\([^)]*\)"#, in: text, excluding: excluding) { m in
            guard let label = m.range(at: 1).notFound else { return }

            // Hide "[" before label
            hide(NSRange(location: m.range.location, length: 1), in: storage)
            // Hide "](url)" after label
            let suffixLen = m.range.upperBound - label.upperBound
            if suffixLen > 0 {
                hide(NSRange(location: label.upperBound, length: suffixLen), in: storage)
            }
            storage.addAttribute(.foregroundColor, value: linkColor, range: label)
        }
    }

    // MARK: - Regex helpers

    private func eachMatch(_ pattern: String, in text: String, excluding: [NSRange],
                           handler: (NSTextCheckingResult) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let full = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let m = match else { return }
            guard !excluding.overlaps(m.range) else { return }
            handler(m)
        }
    }

    /// Hides opening/closing markers always, but only calls `applyToInner` when
    /// the inner content doesn't overlap with code ranges.
    /// Handles cases like **`code`** — hide ** but don't re-style code content.
    private func eachMatchHideMarkers(_ pattern: String, in text: String,
                                      storage: NSTextStorage, codeBlocks: [NSRange],
                                      markerLen: Int, applyToInner: (NSRange) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let full = NSRange(location: 0, length: (text as NSString).length)

        regex.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let m = match else { return }
            // Skip only if the marker START is inside a code region (e.g., bold inside code block)
            guard !codeBlocks.containsLocation(m.range.location) else { return }
            guard let inner = m.range(at: 1).notFound else { return }

            // Always hide opening & closing markers
            hide(NSRange(location: m.range.location, length: markerLen), in: storage)
            hide(NSRange(location: m.range.upperBound - markerLen, length: markerLen), in: storage)

            // Only apply style to inner content if it doesn't overlap inline code
            if !codeBlocks.overlaps(inner) {
                applyToInner(inner)
            }
        }
    }

    // MARK: - Line helpers

    private func headerLevel(_ line: String) -> Int? {
        var level = 0
        for ch in line {
            guard ch == "#" else { break }
            level += 1
        }
        guard level >= 1, level <= 6 else { return nil }
        let idx = line.index(line.startIndex, offsetBy: level, limitedBy: line.endIndex) ?? line.endIndex
        guard idx < line.endIndex, line[idx] == " " else { return nil }
        return level
    }

    private func isHR(_ line: String) -> Bool {
        let s = line.replacingOccurrences(of: " ", with: "")
        return s == "---" || s == "***" || s == "___"
    }

    private func orderedPrefixLen(_ line: String) -> Int? {
        guard let r = line.range(of: #"^\d+\.\s"#, options: .regularExpression) else { return nil }
        return line.distance(from: line.startIndex, to: r.upperBound)
    }
}

// MARK: - Helpers

private extension [NSRange] {
    func overlaps(_ other: NSRange) -> Bool {
        contains { NSIntersectionRange($0, other).length > 0 }
    }
    /// Returns true if any range contains this exact location
    func containsLocation(_ loc: Int) -> Bool {
        contains { loc >= $0.location && loc < $0.upperBound }
    }
}

private extension NSRange {
    /// Returns self if not NSNotFound, otherwise nil
    var notFound: NSRange? {
        location == NSNotFound ? nil : self
    }
}

// MARK: - NSFont extensions

extension NSFont {
    func addingTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        var t = fontDescriptor.symbolicTraits
        t.insert(traits)
        return NSFont(descriptor: fontDescriptor.withSymbolicTraits(t), size: pointSize) ?? self
    }

    func withBoldWeight() -> NSFont {
        let d = fontDescriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: NSFont.Weight.bold]
        ])
        return NSFont(descriptor: d, size: pointSize) ?? self
    }
}
