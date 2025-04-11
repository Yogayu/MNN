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
    @StateObject private var viewModel: LLMChatViewModel
    @State private var systemReady: Bool = false
    
    init(modelInfo: ModelInfo) {
        let viewModel = LLMChatViewModel(modelInfo: modelInfo, 
                                         enableASR: true, 
                                         enableTTS: true)
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // 背景渐变
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
                // 标题
                HStack {
                    Spacer()
                    Text("语音对话")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.bottom)
                
                if !systemReady {
                    // loading
                    VStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Text("正在初始化...")
                            .font(.body)
                        Text("请稍候，系统正在准备各项功能")
                            .font(.body)
                        Spacer()
                    }
                } else {
                    // Chat Content
                    ScrollView(.vertical, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            LazyVStack(alignment: .leading, spacing: 5) {
                                ForEach(viewModel.messages) { message in
                                    MarkdownMessageView(
                                        text: message.text,
                                        isCurrentUser: message.user.isCurrentUser
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding()
                            .onChange(of: viewModel.messages) { _, messages in
                                guard let lastMessage = messages.last else { return }
                                Task { @MainActor in
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    
                    // bottom record button
                    HStack {
                        Spacer()
                        RecordButton(
                            isRecording: viewModel.asrStatus != .stop,
                            isEnabled: viewModel.canInteract
                        ) {
                            viewModel.toggleRecorder()
                        }
                        Spacer()
                    }
                    .padding(.top)
                }
            }
            .padding()
        
        }
        .onAppear {
            viewModel.onStart()
            checkSystemReady()
        }
        .onDisappear {
            viewModel.onStop()
        }
    }
    
    private func checkSystemReady() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            updateSystemReadyState()
            
            if systemReady {
                timer.invalidate()
            }
        }
    }
    
    private func updateSystemReadyState() {
        DispatchQueue.main.async {
            systemReady = viewModel.isModelLoaded && 
                          viewModel.isTTSInitialized && 
                          viewModel.isASRInitialized
        }
    }
}
