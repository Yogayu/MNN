//
//  RecordButton.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/4/1.
//

import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.customBlue)
                    .frame(width: 64, height: 64)
                    .shadow(radius: 3)
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isRecording)
    }
}
