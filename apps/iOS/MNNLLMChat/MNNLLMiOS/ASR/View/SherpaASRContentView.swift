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
                .padding()
                
                // Chat Content
                ScrollView(.vertical, showsIndicators: true) {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(llmViewModel.messages) { message in
                                Markdown(message.text)
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
                                .padding()
                                .fontWeight(.medium)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .font(.system(size: 18))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(message.user.isCurrentUser ? .black.opacity(0.5) : .black)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .onChange(of: llmViewModel.messages) { _, _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
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
