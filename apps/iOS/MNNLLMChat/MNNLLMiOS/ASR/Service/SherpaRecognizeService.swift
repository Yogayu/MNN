//
//  SherpaRecognizeService.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/3/27.
//

import Foundation
import AVFoundation

class SherpaRecognizeService {
    private var audioEngine: AVAudioEngine? = nil
    private var recognizer: SherpaOnnxRecognizer! = nil
    private var audioSession: AVAudioSession!
    
    var onTextRecognized: ((String) -> Void)?
    var onSentenceComplete: ((String) -> Void)?
    
    init() {
        initRecognizer()
        setupAudioSession()
        initRecorder()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - Recognizer Setup
    private func initRecognizer() {
        let modelConfig = getMNNBilingualStreamZhEnZipformer20230220()
        
        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: 16000,
            featureDim: 80)
        
        var config = sherpaOnnxOnlineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            enableEndpoint: true,
            rule1MinTrailingSilence: 2.4,
            rule2MinTrailingSilence: 1.4,
            rule3MinUtteranceLength: 20,
            decodingMethod: "greedy_search",
            maxActivePaths: 4
        )
        
        recognizer = SherpaOnnxRecognizer(config: &config)
    }
    
    // MARK: - Recorder Setup
    private func initRecorder() {
        print("init recorder")
        audioEngine = AVAudioEngine()
        let inputNode = self.audioEngine?.inputNode
        let bus = 0
        let inputFormat = inputNode?.outputFormat(forBus: bus)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000, channels: 1,
            interleaved: false)!
        
        let converter = AVAudioConverter(from: inputFormat!, to: outputFormat)!
        
        inputNode!.installTap(
            onBus: bus,
            bufferSize: 1024,
            format: inputFormat
        ) { [weak self] buffer, when in
            self?.processAudioBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }
    }
    
    // MARK: - Audio Processing
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outputFormat: AVAudioFormat) {
        var newBufferAvailable = true
        
        let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            if newBufferAvailable {
                outStatus.pointee = .haveData
                newBufferAvailable = false
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
        let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(outputFormat.sampleRate)
                * buffer.frameLength
                / AVAudioFrameCount(buffer.format.sampleRate))!
        
        var error: NSError?
        let _ = converter.convert(
            to: convertedBuffer,
            error: &error,
            withInputFrom: inputCallback)
        
        let array = convertedBuffer.array()
        if !array.isEmpty {
            processRecognition(samples: array)
        }
    }
    
    private func processRecognition(samples: [Float]) {
        recognizer.acceptWaveform(samples: samples)
        while recognizer.isReady() {
            recognizer.decode()
        }
        
        let isEndpoint = recognizer.isEndpoint()
        let text = recognizer.getResult().text
        
        DispatchQueue.main.async { [weak self] in
            if !text.isEmpty {
                self?.onTextRecognized?(text)
            }
            
            if isEndpoint && !text.isEmpty {
                self?.onSentenceComplete?(text)
                self?.recognizer.reset()
            }
        }
    }
    
    // MARK: - Public Methods
    func startRecording() {
        do {
            try audioEngine?.start()
        } catch let error as NSError {
            print("Got an error starting audioEngine: \(error.domain), \(error)")
        }
        print("started")
    }
    
    func stopRecording() {
        audioEngine?.stop()
        print("stopped")
    }
}

