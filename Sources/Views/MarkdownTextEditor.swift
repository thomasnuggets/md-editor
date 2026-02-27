import SwiftUI
import AppKit

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var showFormatting: Bool
    var onTextChange: (String) -> Void
    var coordinator: TextViewCoordinator

    private let highlighter = MarkdownSyntaxHighlighter()

    func makeCoordinator() -> NSTextViewCoordinator {
        NSTextViewCoordinator(parent: self, highlighter: highlighter)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.backgroundColor = NSColor.windowBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 0, height: 32)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        // Register with shared coordinator for toolbar actions
        coordinator.textView = textView
        context.coordinator.tvCoordinator = coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update coordinator reference
        coordinator.textView = textView

        // Only update text content if it has actually changed externally
        if textView.string != text {
            let savedRange = textView.selectedRange()
            textView.string = text
            applyAppearance(to: textView)
            // Restore cursor within bounds
            let len = (text as NSString).length
            let loc = min(savedRange.location, len)
            let length = min(savedRange.length, len - loc)
            textView.setSelectedRange(NSRange(location: loc, length: length))
        } else if context.coordinator.showFormattingChanged(to: showFormatting) {
            // Mode switched without text change
            applyAppearance(to: textView)
        }

        context.coordinator.currentShowFormatting = showFormatting
    }

    private func applyAppearance(to textView: NSTextView) {
        if showFormatting {
            if let storage = textView.textStorage {
                highlighter.highlight(storage)
            }
            // Center the content with a max width
            textView.textContainerInset = NSSize(width: 0, height: 32)
        } else {
            // Source mode: plain monospace
            if let storage = textView.textStorage {
                storage.setAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.labelColor
                ], range: NSRange(location: 0, length: (textView.string as NSString).length))
            }
            textView.textContainerInset = NSSize(width: 0, height: 32)
        }
    }
}

// MARK: - Coordinator

class NSTextViewCoordinator: NSObject, NSTextViewDelegate {
    var parent: MarkdownTextEditor
    var tvCoordinator: TextViewCoordinator?
    var currentShowFormatting: Bool
    private let highlighter: MarkdownSyntaxHighlighter
    private var highlightWorkItem: DispatchWorkItem?

    init(parent: MarkdownTextEditor, highlighter: MarkdownSyntaxHighlighter) {
        self.parent = parent
        self.currentShowFormatting = parent.showFormatting
        self.highlighter = highlighter
    }

    func showFormattingChanged(to new: Bool) -> Bool {
        return new != currentShowFormatting
    }

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView else { return }
        let newText = tv.string

        // Update bindings
        DispatchQueue.main.async {
            self.parent.text = newText
            self.parent.onTextChange(newText)
        }

        // Debounced syntax highlighting
        if parent.showFormatting, let storage = tv.textStorage {
            highlightWorkItem?.cancel()
            let capturedStorage = storage
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                // Save/restore cursor
                let range = tv.selectedRange()
                self.highlighter.highlight(capturedStorage)
                tv.setSelectedRange(range)
            }
            highlightWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView else { return }
        tvCoordinator?.lastKnownRange = tv.selectedRange()
    }
}
