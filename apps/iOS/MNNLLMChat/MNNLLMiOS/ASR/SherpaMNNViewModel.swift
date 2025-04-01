//
//  SherpaMNNViewModel.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/3/27.
//

import Foundation
import AVFoundation

enum RecognizerStatus {
    case stop
    case recording
}

@MainActor
class SherpaMNNViewModel: ObservableObject {
    @Published var status: RecognizerStatus = .stop
    @Published var subtitles: String = ""
    
    var onSentenceComplete: ((String) -> Void)?

    private var sentences: [String] = []
    private var lastSentence: String = ""
    private let maxSentence: Int = 20

    private let recognizeService: SherpaRecognizeService

    init() {
        recognizeService = SherpaRecognizeService()
        setupCallbacks()
    }

    private func setupCallbacks() {
        recognizeService.onTextRecognized = { [weak self] text in
            guard let self = self else { return }
            if self.lastSentence != text {
                self.lastSentence = text
                self.updateLabel()
                print("onTextRecognized: \(text)")
            }
        }
        
        recognizeService.onSentenceComplete = { [weak self] text in
            guard let self = self else { return }
            let tmp = self.lastSentence
            self.lastSentence = ""
            self.sentences.append(tmp)
            self.updateLabel()
            print("onSentenceComplete: \(tmp)")
            self.onSentenceComplete?(tmp)
        }
    }

    var results: String {
        if sentences.isEmpty && lastSentence.isEmpty {
            return ""
        }
        if sentences.isEmpty {
            return "0: \(lastSentence.lowercased())"
        }

        let start = max(sentences.count - maxSentence, 0)
        if lastSentence.isEmpty {
            return sentences.enumerated().map { (index, s) in
                "\(index): \(s.lowercased())"
            }[start...]
            .joined(separator: "\n")
        } else {
            return sentences.enumerated().map { (index, s) in
                "\(index): \(s.lowercased())"
            }[start...]
            .joined(separator: "\n")
                + "\n\(sentences.count): \(lastSentence.lowercased())"
        }
    }

    func updateLabel() {
        self.subtitles = self.results
    }

    public func toggleRecorder() {
        if status == .stop {
            startRecorder()
            status = .recording
        } else {
            stopRecorder()
            status = .stop
        }
    }

    public func startRecorder() {
        lastSentence = ""
        sentences = []
        recognizeService.startRecording()
    }

    public func stopRecorder() {
        recognizeService.stopRecording()
    }
}
