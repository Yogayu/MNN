//
//  LLMChatViewModel.swift
//  MNNLLMiOS
//  Created by 游薪渝(揽清) on 2025/1/8.
//

import Combine
import SwiftUI
import AVFoundation

import ExyteChat
import ExyteMediaPicker


final class LLMChatViewModel: ObservableObject {
    
    private var llm: LLMInferenceEngineWrapper?
    private var diffusion: DiffusionSession?
    private let llmState = LLMState()
    
    @Published var messages: [Message] = []
    @Published var isModelLoaded = false
    @Published var isTTSInitialized = false
    @Published var isASRInitialized = false
    @Published var isProcessing: Bool = false
    @Published var isAudioPlaying: Bool = false
    
    @Published var useMmap: Bool = false
    
    @Published var canRecord: Bool = true
    private let audioQueueManager = AudioQueueManager.shared
    private var audioStateSubscription: AnyCancellable?
    
    @Published var asrStatus: RecognizerStatus = .stop
    @Published var asrSubtitles: String = ""
    private var asrService: SherpaRecognizeService?
    private var sentences: [String] = []
    private var lastSentence: String = ""
    private var maxSentence: Int = 20
    
    private var accumulatedText: String = ""
    private var check_next: Bool = false
    private var audioPlayer: AudioPlayer?
    private var ttsService: TTSServiceWrappeer?
    
    var chatInputUnavilable: Bool {
        return !canInteract
    }
    
    var chatStatus: String {
        if isModelLoaded {
            if isProcessing {
                "Processing..."
            } else {
                "Ready"
            }
        } else {
            "Model Loading..."
        }
    }
    
    var chatCover: URL? {
        interactor.otherSenders.count == 1 ? interactor.otherSenders.first!.avatar : nil
    }

    private let interactor: LLMChatInteractor
    private var subscriptions = Set<AnyCancellable>()

    var modelInfo: ModelInfo
    var history: ChatHistory?
    private var historyId: String
    
    let modelConfigManager: ModelConfigManager
    
    var isDiffusionModel: Bool {
        return modelInfo.name.lowercased().contains("diffusion")
    }

    var onStreamOutput: ((String, Bool) -> Void)?
    
    @Published var canInteract: Bool = false
    
    private var enableASR: Bool = false
    private var enableTTS: Bool = false
    
    init(modelInfo: ModelInfo, 
         history: ChatHistory? = nil, 
         enableASR: Bool = false, 
         enableTTS: Bool = false) {
        
        self.modelInfo = modelInfo
        self.history = history
        self.historyId = history?.id ?? UUID().uuidString
        let messages = self.history?.messages
        self.interactor = LLMChatInteractor(modelInfo: modelInfo, historyMessages: messages)
        
        self.modelConfigManager = ModelConfigManager(modelPath: modelInfo.localPath)
        self.useMmap = self.modelConfigManager.readUseMmap()
        
        self.enableASR = enableASR
        self.enableTTS = enableTTS
        
        if !enableASR {
            self.isASRInitialized = true
        }
        
        if !enableTTS {
            self.isTTSInitialized = true
        }
    }
    
    deinit {
        print("yxy:: LLMChat View Model deinit")
    }
    
    func setupLLM(modelPath: String) {
        Task { @MainActor in
            self.send(draft: DraftMessage(
                text: NSLocalizedString("ModelLoadingText", comment: ""),
                thinkText: "",
                medias: [],
                recording: nil,
                replyMessage: nil,
                createdAt: Date()
            ), userType: .system)
        }

        if modelInfo.name.lowercased().contains("diffusion") {
            diffusion = DiffusionSession(modelPath: modelPath, completion: { [weak self] success in
                Task { @MainActor in
                    print("Diffusion Model \(success)")
                    self?.isModelLoaded = success
                    self?.sendModelLoadStatus(success: success)
                    self?.updateInteractionState()
                }
            })
        } else {
            llm = LLMInferenceEngineWrapper(modelPath: modelPath) { [weak self] success in
                Task { @MainActor in
                    self?.isModelLoaded = success
                    self?.sendModelLoadStatus(success: success)
                    self?.processHistoryMessages()
                    self?.updateInteractionState()
                }
            }
        }
    }
    
    private func sendModelLoadStatus(success: Bool) {
        let modelLoadSuccessText = NSLocalizedString("ModelLoadingSuccessText", comment: "")
        let modelLoadFailText = NSLocalizedString("ModelLoadingFailText", comment: "")
        let loadResult = success ? modelLoadSuccessText : modelLoadFailText

        self.send(draft: DraftMessage(
            text: loadResult,
            thinkText: "",
            medias: [],
            recording: nil,
            replyMessage: nil,
            createdAt: Date()
        ), userType: .system)
    }
    
    private func processHistoryMessages() {
        guard let history = self.history else { return }
        
        let historyPrompts = history.messages.flatMap { msg -> [[String: String]] in
            var prompts: [[String: String]] = []
            let sender = msg.isUser ? "user" : "assistant"
            
            prompts.append([sender: msg.content])
            
            if let images = msg.images {
                let imgStr = images.map { "<img>\($0.full.path)</img>" }.joined()
                prompts.append([sender: imgStr])
            }
            
            if let audio = msg.audio, let url = audio.url {
                prompts.append([sender: "<audio>\(url.path)</audio>"])
            }
            
            return prompts
        }
        
        let nsArray = historyPrompts as [[AnyHashable: Any]]
        llm?.addPrompts(from: nsArray)
    }
    
    func sendToLLM(draft: DraftMessage) {
        self.send(draft: draft, userType: .user)
        if isModelLoaded {
            if modelInfo.name.lowercased().contains("diffusion") {
                self.getDiffusionResponse(draft: draft)
            } else {
                self.getLLMRespsonse(draft: draft)
            }
        }
    }
    
    func send(draft: DraftMessage, userType: UserType) {
        interactor.send(draftMessage: draft, userType: userType)
    }
    
    func getDiffusionResponse(draft: DraftMessage) {
        
        Task {
            
            let tempDir = FileManager.default.temporaryDirectory
            let imageName = UUID().uuidString + ".jpg"
            let tempImagePath = tempDir.appendingPathComponent(imageName).path

            var lastProcess:Int32 = 0
            
            self.send(draft: DraftMessage(text: "Start Generating Image...", thinkText: "", medias: [], recording: nil, replyMessage: nil, createdAt: Date()), userType: .assistant)
            
            // 获取用户设置的迭代次数和种子值
            let userIterations = self.modelConfigManager.readIterations()
            let userSeed = self.modelConfigManager.readSeed()
            
            // 使用用户设置的参数调用新方法
            diffusion?.run(withPrompt: draft.text, 
                          imagePath: tempImagePath, 
                         iterations: Int32(userIterations), 
                               seed: Int32(userSeed),
                    progressCallback: {progress in
                if progress == 100 {
                    self.send(draft: DraftMessage(text: "Image generated successfully!", thinkText: "", medias: [], recording: nil, replyMessage: nil, createdAt: Date()), userType: .system)
                    self.interactor.sendImage(imageURL: URL(string: "file://" + tempImagePath)!)
                } else if ((progress - lastProcess) > 20) {
                    lastProcess = progress
                    self.send(draft: DraftMessage(text: "Generating Image \(progress)%", thinkText: "", medias: [], recording: nil, replyMessage: nil, createdAt: Date()), userType: .system)
                }
            })
        }
    }
    
    func getLLMRespsonse(draft: DraftMessage) {
        Task {
            await llmState.setProcessing(true)
            await MainActor.run { 
                self.isProcessing = true
                self.updateInteractionState()
            }
            
            var content = draft.text
            let medias = draft.medias
            
            // MARK: Add image
            for media in medias {
                guard media.type == .image, let url = await media.getURL() else {
                    continue
                }

                let isInTempDirectory = url.path.contains("/tmp/")
                let fileName = url.lastPathComponent
                
                if !isInTempDirectory {
                    guard let fileUrl = AssetExtractor.copyFileToTmpDirectory(from: url, fileName: fileName) else {
                        continue
                    }
                    let processedUrl = convertHEICImage(from: fileUrl)
                    content = "<img>\(processedUrl?.path ?? "")</img>" + content
                } else {
                    let processedUrl = convertHEICImage(from: url)
                    content = "<img>\(processedUrl?.path ?? "")</img>" + content
                }
            }
            
            if let audio = draft.recording, let path = audio.url {
//                if let wavFile = await convertACCToWAV(accFileUrl: path) {
                content = "<audio>\(path.path)</audio>" + content
//                }
            }
            
            let convertedContent = self.convertDeepSeekMutliChat(content: content)
            
            await llmState.processContent(convertedContent, llm: self.llm) { [weak self] output in
                Task { @MainActor in
                    let ended = output.contains("<eop>")
                    if ended {
                        self?.isProcessing = false
                        await self?.llmState.setProcessing(false)
                        self?.updateInteractionState()
                    } else {
                        self?.send(draft: DraftMessage(
                            text: output,
                            thinkText: "",
                            medias: [],
                            recording: nil,
                            replyMessage: nil,
                            createdAt: Date()
                        ), userType: .assistant)
                    }
                    
                    if ((self?.ttsService) != nil){
                        self?.processTTS(text: output, ended: ended)
                    }
                }
            }
        }
    }
    
    func setModelConfig() {
        if let configStr = self.modelConfigManager.readConfigAsJSONString(), let llm = self.llm {
            llm.setConfigWithJSONString(configStr)
        }
    }
    
    private func convertDeepSeekMutliChat(content: String) -> String {
        if self.modelInfo.name.lowercased().contains("deepseek") {
            /* formate:: <|begin_of_sentence|><|User|>{text}<|Assistant|>{text}<|end_of_sentence|>
             <|User|>{text}<|Assistant|>{text}<|end_of_sentence|>
             */
            var deepSeekContent = "<|begin_of_sentence|>"
            
            for message in messages {
                let senderTag: String
                switch message.user.id {
                case "1":
                    senderTag = "<|User|>"
                case "2":
                    senderTag = "<|Assistant|>"
                default:
                    continue
                }
                deepSeekContent += "\(senderTag)\(message.text)"
            }
            
            deepSeekContent += "<|end_of_sentence|><think><\n>"
            print(deepSeekContent)
            return deepSeekContent
        } else {
            return content
        }
    }
    
    private func convertHEICImage(from url: URL) -> URL? {
        var fileUrl = url
        if fileUrl.isHEICImage() {
            if let convertedUrl = AssetExtractor.convertHEICToJPG(heicUrl: fileUrl) {
                fileUrl = convertedUrl
            }
        }
        return fileUrl
    }
    
    func onStart() {
        interactor.messages
            .compactMap { messages in
                messages.map { $0.toChatMessage() }
            }
            .assign(to: &$messages)

        interactor.connect()
        
        if enableTTS {
            setupTTS()
        }
        
        if enableASR {
            initializeASR()
        }
        
        self.setupLLM(modelPath: self.modelInfo.localPath)
    }

    func onStop() {
        ChatHistoryManager.shared.saveChat(
            historyId: historyId,
            modelId: modelInfo.modelId,
            modelName: modelInfo.name,
            messages: messages
        )
        
        interactor.disconnect()
        llm = nil
        self.cleanTmpFolder()
        
        audioQueueManager.clearQueue()
        audioStateSubscription?.cancel()
        
        if enableTTS {
            audioPlayer?.stop()
            audioPlayer = nil
            ttsService = nil
        }
        
        if enableASR {
            stopRecorder()
            asrService = nil
        }
    }

    func loadMoreMessage(before message: Message) {
        interactor.loadNextPage()
            .sink { _ in }
            .store(in: &subscriptions)
    }
    
    
    func cleanModelTmpFolder() {
        let tmpFolderURL = URL(fileURLWithPath: self.modelInfo.localPath).appendingPathComponent("temp")
        self.cleanFolder(tmpFolderURL: tmpFolderURL)
    }
    
    private func cleanTmpFolder() {
        let fileManager = FileManager.default
        let tmpDirectoryURL = fileManager.temporaryDirectory
        
        self.cleanFolder(tmpFolderURL: tmpDirectoryURL)
        
        if !useMmap {
            cleanModelTmpFolder()
        }
    }
    
    private func cleanFolder(tmpFolderURL: URL) {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: tmpFolderURL, includingPropertiesForKeys: nil)
            for file in files {
                if !file.absoluteString.lowercased().contains("networkdownload") {
                    do {
                        try fileManager.removeItem(at: file)
                        print("Deleted file: \(file.path)")
                    } catch {
                        print("Error deleting file: \(file.path), \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Error accessing tmp directory: \(error.localizedDescription)")
        }
    }
    
    /// MARK: TTS
    func setupTTS() {
        
        guard enableTTS else {
            self.isTTSInitialized = true
            updateInteractionState()
            return
        }
        
        self.audioPlayer = AudioPlayer()
        
        ttsService = TTSServiceWrappeer { [weak self] success in
            if success {
                print("TTS 初始化成功")
                DispatchQueue.main.async {
                    self?.isTTSInitialized = true
                    self?.updateInteractionState()
                }
            } else {
                print("TTS 初始化失败")
                DispatchQueue.main.async {
                    self?.isTTSInitialized = false
                    self?.updateInteractionState()
                }
            }
        }
        
        audioPlayer?.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.isAudioPlaying = state == .playing
                self?.canRecord = state != .playing
                self?.updateInteractionState()
            }
        }
        
        ttsService?.setHandler { [weak self] buffer, length, sampleRate, duration, isEOP in
            if let buffer = buffer {
                DispatchQueue.main.async {
                    self?.isAudioPlaying = true
                    self?.updateInteractionState()
                }
                
                self?.audioPlayer?.play(buffer, length: length, sampleRate: 44100)
            }
        }
    }
    
    private func processTTS(text: String, ended: Bool) {
        guard enableTTS else { return }
        
        if text.hasSuffix("。") || text.hasSuffix("，") ||
           text.hasSuffix("！") || text.hasSuffix("？") {
            self.accumulatedText += text
            self.check_next = true
            
            if !self.accumulatedText.isEmpty {
                ttsService?.play(self.accumulatedText, isEOP: false)
                self.accumulatedText = ""
            }
            
        } else if ended {
            let textToPlay = self.accumulatedText + text
            if !textToPlay.isEmpty {
                ttsService?.play(textToPlay.replacingOccurrences(of: "<eop>", with: ""), isEOP: true)
                self.accumulatedText = ""
            }
            
        } else {
            if self.check_next, self.accumulatedText.count > 5 {
                ttsService?.play(self.accumulatedText, isEOP: false)
                self.accumulatedText = ""
            }
            self.check_next = false
            self.accumulatedText += text
        }
    }
    
    private func updateInteractionState() {
        
        let canInteract = isModelLoaded &&
                          isTTSInitialized && 
                          isASRInitialized && 
                          !isProcessing && 
                          !isAudioPlaying
        
        DispatchQueue.main.async {
            self.canInteract = canInteract
            
            // 如果状态从不可交互变为可交互，并且之前在录音且ASR启用
            if canInteract && self.asrStatus == .recording && self.enableASR {
                self.startRecorder()
            }
            // 如果状态从可交互变为不可交互，并且正在录音且ASR启用
            else if !canInteract && self.asrStatus == .recording && self.enableASR {
                self.stopRecorder()
            }
        }
    }
    
    // MARK: - ASR 功能整合
    
    /// 初始化 ASR 服务
    func initializeASR() {
        // 仅当启用 ASR 时才初始化
        guard enableASR else {
            self.isASRInitialized = true
            updateInteractionState()
            return
        }
        
        // 初始化 ASR 服务
        self.asrService = SherpaRecognizeService()
        
        // 设置回调
        setupASRCallbacks()
        
        // 延迟一点时间来模拟初始化过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.isASRInitialized = true
            self.updateInteractionState()
        }
    }
    
    private func setupASRCallbacks() {
        asrService?.onTextRecognized = { [weak self] text in
            guard let self = self else { return }
            Task { @MainActor in
                if self.lastSentence != text {
                    self.lastSentence = text
                    self.updateLabel()
                }
            }
        }
        
        asrService?.onSentenceComplete = { [weak self] text in
            guard let self = self else { return }
            Task { @MainActor in
                let tmp = self.lastSentence
                self.lastSentence = ""
                self.sentences.append(tmp)
                self.updateLabel()
                
                // 当句子完成时，自动发送到 LLM
                self.sendASRTextToLLM(text: tmp)
            }
        }
    }
    
    /// 更新 ASR 字幕
    private func updateLabel() {
        if sentences.isEmpty && lastSentence.isEmpty {
            asrSubtitles = ""
            return
        }
        
        if sentences.isEmpty {
            asrSubtitles = "0: \(lastSentence.lowercased())"
            return
        }
        
        let start = max(sentences.count - maxSentence, 0)
        if lastSentence.isEmpty {
            asrSubtitles = sentences.enumerated().map { (index, s) in
                "\(index): \(s.lowercased())"
            }[start...]
            .joined(separator: "\n")
        } else {
            asrSubtitles = sentences.enumerated().map { (index, s) in
                "\(index): \(s.lowercased())"
            }[start...]
            .joined(separator: "\n")
                + "\n\(sentences.count): \(lastSentence.lowercased())"
        }
    }
    
    /// 切换录音状态
    func toggleRecorder() {
        // 只有当 ASR 启用时才执行
        guard enableASR else { return }
        
        if asrStatus == .stop {
            startRecorder()
        } else {
            stopRecorder()
        }
    }
    
    /// 开始录音
    func startRecorder() {
        // 只有当 ASR 启用且可交互时才执行
        guard enableASR && canInteract else { return }
        
        lastSentence = ""
        sentences = []
        asrService?.startRecording()
        asrStatus = .recording
    }
    
    /// 停止录音
    func stopRecorder() {
        // 只有当 ASR 启用时才执行
        guard enableASR else { return }
        
        asrService?.stopRecording()
        asrStatus = .stop
    }
    
    /// 将 ASR 识别的文本发送到 LLM
    func sendASRTextToLLM(text: String) {
        guard !text.isEmpty, canInteract else { return }
        
        let draft = DraftMessage(
            text: text,
            thinkText: "",
            medias: [],
            recording: nil,
            replyMessage: nil,
            createdAt: Date()
        )
        
        sendToLLM(draft: draft)
    }
}
