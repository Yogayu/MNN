//
//  RecordButton.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/4/1.
//

import SwiftUI
import MarkdownUI

struct MarkdownMessageView: View {
    let text: String
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
//            if isCurrentUser {
//                Image(systemName: "person.circle.fill")
//                    .foregroundColor(.blue)
//                    .font(.title2)
//            } else {
//                Image(ImageResource.mnnIcon)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 26, height: 26)
//                    .cornerRadius(13)
//                    .foregroundColor(.blue)
//            }
            Markdown(text)
                .markdownBlockStyle(\.blockquote) { configuration in
                    configuration.label
                        .padding()
                        .markdownTextStyle {
                            FontSize(16)
                            FontWeight(.medium)
                            BackgroundColor(nil)
                        }
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 4)
                        }
                        .background(Color.gray.opacity(0.2))
                }
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(18)
                    ForegroundColor(isCurrentUser ? .customBlue : .black)
                }
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .padding(.vertical, 4)
    }
}
