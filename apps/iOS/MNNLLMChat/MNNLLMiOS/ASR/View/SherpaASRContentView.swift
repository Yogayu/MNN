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
    
    @State private var canRecord: Bool = true
    @State private var accumulatedText: String = ""
    @State private var check_next: Bool = false
    @StateObject var sherpaVM = SherpaMNNViewModel()
    @StateObject private var llmViewModel: LLMChatViewModel
    @State private var audioPlayer = AudioPlayer()
    @State private var ttsService: TTSServiceWrappeer?
    
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
                                 isEnabled: canRecord) {
                        toggleRecorder()
                    }
                    Spacer()
                }
                .padding(.top)
            }
            .padding()
            .onAppear {
                setupTTS()
                setupCallbacks()
                llmViewModel.onStart()

                llmViewModel.onStreamOutput = { [weak ttsService] text, ended in
                    if text.hasSuffix("。") || text.hasSuffix("，") || 
                       text.hasSuffix("！") || text.hasSuffix("？") {
                        self.accumulatedText += text
                        self.check_next = true
                        ttsService?.play(self.accumulatedText, isEOP: false)
                        self.accumulatedText = ""
                    } else if ended {
                        let textToPlay = self.accumulatedText + text
                        if !textToPlay.isEmpty {
                            ttsService?.play(textToPlay, isEOP: true)
                            self.accumulatedText = ""
                        }
                    } else {
                        if self.check_next, self.accumulatedText.count > 5 {
                            ttsService?.play(self.accumulatedText, isEOP: false)
                            self.accumulatedText = ""
                        }
                        self.check_next = false
                        self.accumulatedText += text
                    }
                }
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
    
    private func setupTTS() {
        
        ttsService = TTSServiceWrappeer { success in
            if success {
                print("TTS 初始化成功")
            } else {
                print("TTS 初始化失败")
            }
        }
        
        ttsService?.setHandler { [weak audioPlayer] buffer, length, sampleRate, duration, isEOP in
            if let buffer = buffer {
                audioPlayer?.play(buffer, length: length, sampleRate: 44100)
            }
        }
    }
}


struct MessageBubble: View {
    let text: String
    let isCurrentUser: Bool
    let showIcon: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser && showIcon {
                Image(ImageResource.mnnIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .cornerRadius(13)
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            
            Text(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(20)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isCurrentUser ? .trailing : .leading)

            if isCurrentUser && showIcon {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .padding(.vertical, 4)
    }
}
