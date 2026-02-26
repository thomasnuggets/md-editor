import AppKit
import WebKit
import PDFKit

class ExportService {

    func exportPDF(html: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName + ".pdf"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 794, height: 1123))
        webView.loadHTMLString(html, baseURL: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let config = WKPDFConfiguration()
            webView.createPDF(configuration: config) { result in
                switch result {
                case .success(let data):
                    try? data.write(to: url)
                case .failure(let error):
                    print("PDF export error: \(error)")
                }
            }
        }
    }
}
