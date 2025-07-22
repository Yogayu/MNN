//
//  DebugLocalModelView.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/7/22.
//

import SwiftUI

struct DebugLocalModelView: View {
    @State private var availableModels: [String] = []
    @State private var selectedModel: String? = nil
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var debugResult = ""
    @State private var showChatView = false
    @State private var chatModelName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题和说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("本地模型调试")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("选择LocalModel文件夹下的模型进行调试测试")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // 可用模型列表
                if availableModels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("未找到可用的本地模型")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("请确保在LocalModel文件夹下放置了有效的模型文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section("可用模型 (\(availableModels.count))") {
                            ForEach(availableModels, id: \.self) { modelName in
                                DebugModelRowView(
                                    modelName: modelName,
                                    isSelected: selectedModel == modelName,
                                    onSelect: {
                                        selectedModel = modelName
                                    },
                                    onDebug: {
                                        debugModel(modelName)
                                    },
                                    onChat: {
                                        chatModelName = modelName
                                        showChatView = true
                                    }
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                
                // 调试结果显示
                if !debugResult.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("调试结果")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ScrollView {
                            Text(debugResult)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 150)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("本地调试")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadAvailableModels()
            }
            .alert("调试结果", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showChatView) {
                DebugChatView(modelName: chatModelName)
            }
        }
    }
    
    private func loadAvailableModels() {
        // 调用Objective-C接口获取可用模型
        let models = LLMInferenceEngineWrapper.getAvailableBundledModels()
        availableModels = models
        debugResult = "发现 \(models.count) 个可用模型: \(models.joined(separator: ", "))"
    }
    
    private func debugModel(_ modelName: String) {
        isLoading = true
        debugResult = "正在调试模型: \(modelName)..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 检查模型是否可用
            let isAvailable = LLMInferenceEngineWrapper.isBundledModelAvailable(modelName)
            
            guard isAvailable else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "模型 '\(modelName)' 不可用"
                    self.showAlert = true
                    self.debugResult = "❌ 模型 '\(modelName)' 不可用"
                }
                return
            }
            
            // 获取模型路径
            guard let modelPath = LLMInferenceEngineWrapper.getBundledModelPath(modelName) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "无法获取模型 '\(modelName)' 的路径"
                    self.showAlert = true
                    self.debugResult = "❌ 无法获取模型路径"
                }
                return
            }
            
            // 尝试加载模型
            let engine = LLMInferenceEngineWrapper()
            let success = engine.loadBundledModel(modelName)
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.alertMessage = "模型 '\(modelName)' 加载成功！\n路径: \(modelPath)"
                    self.debugResult = "✅ 模型 '\(modelName)' 加载成功\n📁 路径: \(modelPath)\n🔧 可以开始调试对话"
                } else {
                    self.alertMessage = "模型 '\(modelName)' 加载失败"
                    self.debugResult = "❌ 模型 '\(modelName)' 加载失败\n📁 路径: \(modelPath)"
                }
                
                self.showAlert = true
            }
        }
    }
}

struct DebugModelRowView: View {
    let modelName: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onDebug: () -> Void
    let onChat: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(modelName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let modelPath = LLMInferenceEngineWrapper.getBundledModelPath(modelName) {
                    Text(modelPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("测试") {
                    onDebug()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("对话") {
                    onChat()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    DebugLocalModelView()
}
