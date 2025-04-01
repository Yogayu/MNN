//
//  SherpaASRContentView.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/3/26.
//

import SwiftUI
import AVFoundation
import ExyteChat

struct SherpaASRContentView: View {
    
    @State private var canRecord: Bool = true
    @StateObject var sherpaVM = SherpaMNNViewModel()
    @StateObject private var llmViewModel: LLMChatViewModel
    
    init(modelInfo: ModelInfo) {
        let viewModel = LLMChatViewModel(modelInfo: modelInfo)
        _llmViewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            Text("ASR LLM Chat")
                .font(.title)
            
            ScrollView(.vertical, showsIndicators: true) {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 10) {
                        if !sherpaVM.subtitles.isEmpty {
                            Text("语音识别结果:")
                                .font(.headline)
                            Text(sherpaVM.subtitles)
                                .padding(.horizontal)
                        }
                        
                        if !llmViewModel.messages.isEmpty {
                            Text("Chat Content")
                                .font(.headline)
                            ForEach(llmViewModel.messages) { message in
                                Text(message.text)
                                    .padding(.horizontal)
                                    .foregroundColor(message.user.isCurrentUser ? .gray : .black)
                                    .fontWeight(.medium)
                                    .id(message.id)
                            }
                        }
                        Color.clear.frame(height: 1)
                            .id("bottom")
                    }
                    .onChange(of: llmViewModel.messages) { _, messages in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button {
                    toggleRecorder()
                } label: {
                    Text(sherpaVM.status == .stop ? "开始录音" : "停止录音")
                        .padding()
                        .background(sherpaVM.status == .stop ? Color.blue : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!canRecord)
            }
        }
        .padding()
        .onAppear {
            setupCallbacks()
            llmViewModel.onStart()
        }
        .onDisappear {
            llmViewModel.onStop()
        }
        .onChange(of: llmViewModel.isProcessing) { oldValue, isProcessing in
            if isProcessing {
                if sherpaVM.status != .stop {
                    sherpaVM.stopRecorder()
                    sherpaVM.status = .stop
                }
                canRecord = false
            } else {
                if sherpaVM.status == .stop {
                    sherpaVM.startRecorder()
                    sherpaVM.status = .recording
                }
                canRecord = true
            }
        }
    }
    
    private func setupCallbacks() {
        sherpaVM.onSentenceComplete = { text in
            Task { @MainActor in
                sendToLLM(text: text)
            }
        }
    }
    
    private func toggleRecorder() {
        sherpaVM.toggleRecorder()
    }
    
    private func sendToLLM(text: String) {
        guard !sherpaVM.subtitles.isEmpty else { return }
        
        let draft = DraftMessage(
            text: text,
            thinkText: "",
            medias: [],
            recording: nil,
            replyMessage: nil,
            createdAt: Date()
        )
        
        llmViewModel.sendToLLM(draft: draft)
    }
}
