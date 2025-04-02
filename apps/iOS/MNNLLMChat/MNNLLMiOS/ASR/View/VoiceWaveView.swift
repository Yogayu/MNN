//
//  SherpaASRContentView.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/3/26.
//

import SwiftUI

struct VoiceWaveView: View {
    let isProcessing: Bool
    
    @State private var waveScale: CGFloat = 1.0
    @State private var waveOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 60, height: 60)
            
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.customBlue, lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(waveScale)
                    .opacity(waveOpacity)
            }
            
            Image(systemName: "waveform")
                .font(.system(size: 24))
                .foregroundColor(.customBlue)
        }
        .frame(width: 120, height: 120)
        .drawingGroup()
        .onChange(of: isProcessing) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    waveScale = 1.8
                    waveOpacity = 0
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    waveScale = 1.0
                    waveOpacity = 0.3
                }
            }
        }
    }
}
