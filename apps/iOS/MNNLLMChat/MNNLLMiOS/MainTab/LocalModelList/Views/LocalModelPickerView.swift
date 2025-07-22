//
//  LocalModelPickerView.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/7/22.
//

import SwiftUI

struct LocalModelPickerView: View {
    let availableModels: [String]
    let onModelSelected: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModel: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 头部信息
                headerView
                
                // 模型列表
                if availableModels.isEmpty {
                    emptyStateView
                } else {
                    modelListView
                }
                
                Spacer()
                
                // 底部按钮
                bottomButtonsView
            }
            .navigationTitle("选择本地模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text("LocalModel 文件夹")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(availableModels.count) 个模型")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("选择一个本地模型进入对话界面")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("未找到本地模型")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("请将 .mnn 模型文件放入 LocalModel 文件夹中")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var modelListView: some View {
        List {
            ForEach(availableModels, id: \.self) { modelName in
                LocalModelRowItem(
                    modelName: modelName,
                    isSelected: selectedModel == modelName,
                    onTap: {
                        selectedModel = modelName
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private var bottomButtonsView: some View {
        VStack(spacing: 12) {
            if let selected = selectedModel {
                Button(action: {
                    onModelSelected(selected)
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("开始对话")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
            
            Button(action: {
                dismiss()
            }) {
                Text("取消")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct LocalModelRowItem: View {
    let modelName: String
    let isSelected: Bool
    let onTap: () -> Void
    
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
                
                HStack(spacing: 8) {
                    Label("本地模型", systemImage: "folder.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    if LLMInferenceEngineWrapper.isBundledModelAvailable(modelName) {
                        Label("可用", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Label("不可用", systemImage: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    LocalModelPickerView(
        availableModels: ["test-model-1", "test-model-2"],
        onModelSelected: { _ in }
    )
}
