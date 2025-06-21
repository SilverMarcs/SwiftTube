//
//  String+HTMLParser.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI
import Foundation

extension String {
    /// Converts HTML string to AttributedString with proper formatting and theme-aware styling
    func htmlToAttributedString(font: Font = .subheadline, color: Color = .primary) -> AttributedString {        
        do {
            // Create base HTML with CSS for proper styling
            let htmlWithCSS = """
            <html>
            <head>
            <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                font-size: \(UIFont.preferredFont(forTextStyle: .subheadline).pointSize)px;
                line-height: 1.4;
                margin: 0;
                padding: 0;
            }
            a {
                color: #007AFF;
                text-decoration: none;
            }
            a:hover {
                text-decoration: underline;
            }
            b, strong {
                font-weight: 600;
            }
            i, em {
                font-style: italic;
            }
            </style>
            </head>
            <body>\(self)</body>
            </html>
            """
            
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            guard let htmlData = htmlWithCSS.data(using: .utf8) else {
                return AttributedString(self.strippingHTML())
            }
            
            let nsAttributedString = try NSAttributedString(data: htmlData, options: options, documentAttributes: nil)
            var attributedString = AttributedString(nsAttributedString)
            
            // Apply SwiftUI theme-aware styling
            attributedString = applyThemeAwareAttributes(to: attributedString, font: font, color: color)
            
            return attributedString
        } catch {
            // If HTML parsing fails, strip HTML tags and return plain text
            return AttributedString(self.strippingHTML())
        }
    }
    
    /// Applies theme-aware attributes to AttributedString
    private func applyThemeAwareAttributes(to attributedString: AttributedString, font: Font, color: Color) -> AttributedString {
        var result = attributedString
        
        // Set base font and color for the entire string
        result.font = font
        result.foregroundColor = color
        
        // Process each run to maintain formatting while updating colors
        for run in result.runs {
            let range = run.range
            
            // Preserve bold formatting
            if let nsFont = run.uiKit.font, nsFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
                result[range].font = font.bold()
            }
            
            // Preserve italic formatting
            if let nsFont = run.uiKit.font, nsFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                result[range].font = font.italic()
            }
            
            // Handle links with proper theme colors
            if run.link != nil {
                result[range].foregroundColor = .accentColor
                result[range].underlineStyle = .single
            } else {
                // Ensure all non-link text uses the theme color
                result[range].foregroundColor = color
            }
        }
        
        return result
    }
    
    /// Strips HTML tags from string and returns plain text
    func strippingHTML() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Checks if string contains HTML tags
    var containsHTML: Bool {
        return self.range(of: "<[^>]+>", options: .regularExpression) != nil
    }
}
