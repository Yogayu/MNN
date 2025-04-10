//
//  SherpaASRContentView.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/3/26.
//

import SwiftUI
import ExyteChat
import MarkdownUI

struct SherpaASRContentView: View {
    
    @StateObject var sherpaVM = SherpaMNNViewModel()
    @StateObject private var llmViewModel: LLMChatViewModel
    
    init(modelInfo: ModelInfo) {
        let viewModel = LLMChatViewModel(modelInfo: modelInfo)
        _llmViewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.08),
                    Color.blue.opacity(0.03)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Title
                HStack {
                    Spacer()
                    Text("语音对话")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.bottom)
                
                // Voice Wave Animation
                // VoiceWaveView(isProcessing: llmViewModel.isProcessing)
                //     .drawingGroup()
                
                // Chat Content
                ScrollView(.vertical, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        LazyVStack(alignment: .leading, spacing: 5) {
                            ForEach(llmViewModel.messages) { message in
                                MarkdownMessageView(
                                    text: message.text,
                                    isCurrentUser: message.user.isCurrentUser
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                        .onChange(of: llmViewModel.messages) { _, messages in
                            guard let lastMessage = messages.last else { return }
                            Task { @MainActor in
                                withAnimation(.easeOut(duration: 0.1)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                // Bottom Control
                HStack {
                    Spacer()
                    RecordButton(isRecording: sherpaVM.status != .stop,
                                 isEnabled: !llmViewModel.chatInputUnavilable) {
                        toggleRecorder()
                    }
                    Spacer()
                }
                .padding(.top)
            }
            .padding()
            .onAppear {
                llmViewModel.setupTTS()
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
                } else {
                    if sherpaVM.status == .stop {
                        sherpaVM.startRecorder()
                        sherpaVM.status = .recording
                    }
                }
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
