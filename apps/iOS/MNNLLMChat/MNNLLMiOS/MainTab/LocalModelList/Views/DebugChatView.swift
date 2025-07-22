//
//  DebugChatView.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/7/22.
//

import SwiftUI

struct DebugChatView: View {
    let modelName: String
    
    @State private var messages: [DebugMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var engine: LLMInferenceEngineWrapper?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 模型信息栏
                modelInfoHeader
                
                // 聊天消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                DebugMessageView(message: message)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 输入栏
                inputBar
            }
            .navigationTitle("调试对话")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") {
                        messages.removeAll()
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
        .onAppear {
            initializeEngine()
        }
        .alert("错误", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    @ViewBuilder
    private var modelInfoHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                
                Text("调试模型: \(modelName)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let modelPath = LLMInferenceEngineWrapper.getBundledModelPath(modelName) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    Text(modelPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("输入测试消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .top
        )
    }
    
    private func initializeEngine() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let newEngine = LLMInferenceEngineWrapper()
            let success = newEngine.loadBundledModel(modelName)
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.engine = newEngine
                    self.messages.append(DebugMessage(
                        content: "✅ 模型 '\(modelName)' 加载成功，可以开始对话测试",
                        isUser: false,
                        isSystem: true
                    ))
                } else {
                    self.alertMessage = "模型 '\(modelName)' 加载失败，无法进行对话测试"
                    self.showAlert = true
                }
            }
        }
    }
    
    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty, let engine = engine else { return }
        
        // 添加用户消息
        messages.append(DebugMessage(content: userMessage, isUser: true))
        inputText = ""
        isLoading = true
        
        // 添加AI回复占位符
        let aiMessageId = UUID()
        messages.append(DebugMessage(id: aiMessageId, content: "正在思考...", isUser: false))
        
        DispatchQueue.global(qos: .userInitiated).async {
            var aiResponse = ""
            
            engine.processInput(userMessage) { output in
                DispatchQueue.main.async {
                    aiResponse += output
                    
                    // 更新AI消息内容
                    if let index = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                        self.messages[index] = DebugMessage(
                            id: aiMessageId,
                            content: aiResponse,
                            isUser: false
                        )
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                // 如果没有收到任何回复，显示错误消息
                if aiResponse.isEmpty {
                    if let index = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                        self.messages[index] = DebugMessage(
                            id: aiMessageId,
                            content: "❌ 模型没有返回回复，请检查模型配置",
                            isUser: false,
                            isSystem: true
                        )
                    }
                }
            }
        }
    }
}

struct DebugMessage: Identifiable {
    var id = UUID()
    let content: String
    let isUser: Bool
    let isSystem: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), content: String, isUser: Bool, isSystem: Bool = false) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.isSystem = isSystem
        self.timestamp = Date()
    }
}

struct DebugMessageView: View {
    let message: DebugMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.isSystem ? .secondary : (message.isUser ? .white : .primary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if message.isSystem {
                                Color.gray.opacity(0.2)
                            } else if message.isUser {
                                Color.blue
                            } else {
                                Color(UIColor.secondarySystemBackground)
                            }
                        }
                    )
                    .cornerRadius(16)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }
}

#Preview {
    DebugChatView(modelName: "test_model")
}
