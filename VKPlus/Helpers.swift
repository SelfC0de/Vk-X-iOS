import SwiftUI
import UIKit
import Foundation
import SwiftSoup

// MARK: - HTML stripping (global, available across all files)
func stripHTML(_ html: String) -> String {
    guard html.contains("<") else { return html }
    return (try? SwiftSoup.parse(html).text()) ?? html
}

// MARK: - Keyboard dismiss helper
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
