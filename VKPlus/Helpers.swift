import Foundation
import SwiftSoup

// MARK: - HTML stripping (global, available across all files)
func stripHTML(_ html: String) -> String {
    guard html.contains("<") else { return html }
    return (try? SwiftSoup.parse(html).text()) ?? html
}
