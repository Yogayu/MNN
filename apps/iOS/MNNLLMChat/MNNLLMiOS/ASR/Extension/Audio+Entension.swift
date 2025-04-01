//
//  Audio+Entension.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/3/27.
//

import AVFoundation

extension AudioBuffer {
    func array() -> [Float] {
        return Array(UnsafeBufferPointer(self))
    }
}

extension AVAudioPCMBuffer {
    func array() -> [Float] {
        return self.audioBufferList.pointee.mBuffers.array()
    }
}
