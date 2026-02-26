import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only reload when HTML actually changes to avoid scroll position reset
        webView.loadHTMLString(html, baseURL: nil)
    }
}
