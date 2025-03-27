//
//  SherpaASRContentView.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/3/26.
//

import SwiftUI
import AVFoundation

struct SherpaASRContentView: View {
    @StateObject var sherpaVM = SherpaMNNViewModel()

    var body: some View {
        VStack {
            Text("ASR with Next-gen Kaldi")
                .font(.title)
            if sherpaVM.status == .stop {
                Text("See https://github.com/k2-fsa/sherpa-onnx")
                Text("Press the Start button to run!")
            }
            ScrollView(.vertical, showsIndicators: true) {
                HStack {
                    Text(sherpaVM.subtitles)
                    Spacer()
                }
            }
            Spacer()
            Button {
                toggleRecorder()
            } label: {
                Text(sherpaVM.status == .stop ? "Start" : "Stop")
            }
        }
        .padding()
    }

    private func toggleRecorder() {
        sherpaVM.toggleRecorder()
    }
}
