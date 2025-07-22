//
//  MNNLLMiOSApp.swift
//  LocalModelListView
//
//  Created by 游薪渝(揽清) on 2025/7/22.
//

import SwiftUI

struct LocalModelListView: View {
    @ObservedObject var viewModel: ModelListViewModel
    @ObservedObject private var debugSettings = DebugSettingsManager.shared
    @State private var showLocalModelPicker = false
    @State private var availableLocalModels: [String] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 调试工具栏 - 只在调试模式开启时显示
            if debugSettings.isDebugModeEnabled {
                debugToolbar
            }
            
            // 模型列表
            List {
                ForEach(viewModel.filteredModels.filter { $0.isDownloaded }, id: \.id) { model in
                    Button(action: {
                        viewModel.selectModel(model)
                    }) {
                        LocalModelRowView(model: model)
                    }
                    .listRowBackground(viewModel.pinnedModelIds.contains(model.id) ? Color.black.opacity(0.05) : Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        SwipeActionsView(model: model, viewModel: viewModel)
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.fetchModels()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $showLocalModelPicker) {
            LocalModelPickerView(
                availableModels: availableLocalModels,
                onModelSelected: { modelName in
                    loadLocalModel(modelName)
                }
            )
        }
        .onAppear {
            loadAvailableLocalModels()
        }
    }
    
    @ViewBuilder
    private var debugToolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("本地模型")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("XCode中的模型")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                showLocalModelPicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 14, weight: .medium))
                    Text("调试")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // MARK: - Private Methods
    
    private func loadAvailableLocalModels() {
        availableLocalModels = LLMInferenceEngineWrapper.getAvailableBundledModels()
    }
    
    private func loadLocalModel(_ modelName: String) {
        guard let modelPath = LLMInferenceEngineWrapper.getBundledModelPath(modelName) else {
            return
        }
        
        // 创建本地模型的ModelInfo
        let localModelInfo = ModelInfo(
            modelName: modelName,
            tags: ["本地模型", "调试"],
            categories: ["Local"],
            isDownloaded: true,
            isLocalDebugModel: true
        )
        
        // 设置选中的模型，触发导航到聊天界面
        viewModel.selectModel(localModelInfo)
        
        // 关闭选择器
        showLocalModelPicker = false
    }
}
