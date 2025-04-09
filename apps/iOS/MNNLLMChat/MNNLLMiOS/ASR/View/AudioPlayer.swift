//
//  SherpaASRContentView.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/4/9.
//

import AVFoundation

class AudioPlayer {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var defaultSampleRate: Double = 44100 // 16000 
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let audioEngine = audioEngine,
              let playerNode = playerNode else { return }
        
        audioEngine.attach(playerNode)
        
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                 sampleRate: defaultSampleRate,
                                 channels: 1,
                                 interleaved: false)
        
        if let format = format {
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("音频引擎启动失败: \(error)")
        }
    }
    
    func play(_ buffer: UnsafePointer<Int16>, length: Int, sampleRate: Int32) {
        guard let playerNode = playerNode,
              let audioEngine = audioEngine else { return }
        
        let floatBuffer = UnsafeMutablePointer<Float>.allocate(capacity: length)
        for i in 0..<length {
            floatBuffer[i] = Float(buffer[i]) / Float(Int16.max)
        }
        
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                 sampleRate: Double(sampleRate),
                                 channels: 1,
                                 interleaved: false)
        
        if let format = format {
            let audioBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                             frameCapacity: AVAudioFrameCount(length))
            audioBuffer?.frameLength = AVAudioFrameCount(length)
            
            if let channelData = audioBuffer?.floatChannelData {
                channelData[0].assign(from: floatBuffer, count: length)
            }
            
            playerNode.scheduleBuffer(audioBuffer!, completionHandler: nil)
            playerNode.play()
        }
        
        floatBuffer.deallocate()
    }
    
    func stop() {
        playerNode?.stop()
    }
}
