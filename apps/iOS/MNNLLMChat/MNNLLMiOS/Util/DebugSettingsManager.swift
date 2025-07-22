//
//  DebugSettingsManager.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/7/22.
//

import Foundation

class DebugSettingsManager: ObservableObject {
    static let shared = DebugSettingsManager()
    
    private let debugModeKey = "com.mnnllm.debugMode"
    
    @Published var isDebugModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDebugModeEnabled, forKey: debugModeKey)
        }
    }
    
    private init() {
        self.isDebugModeEnabled = UserDefaults.standard.bool(forKey: debugModeKey)
    }
    
    func toggleDebugMode() {
        isDebugModeEnabled.toggle()
    }
}
