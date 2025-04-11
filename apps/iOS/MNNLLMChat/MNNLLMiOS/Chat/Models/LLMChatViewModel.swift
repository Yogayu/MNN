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
    
    // MARK: - Core Components
    private let interactor: LLMChatInteractor
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - LLM Related
    private var llm: LLMInferenceEngineWrapper?
    private var diffusion: DiffusionSession?
    private let llmState = LLMState()
    
    let modelInfo: ModelInfo
    let modelConfigManager: ModelConfigManager
    var history: ChatHistory?
    private let historyId: String
    
    // MARK: - ASR Related
    private var asrService: SherpaRecognizeService?
    private var sentences: [String] = []
    private var lastSentence: String = ""
    private let maxSentence: Int = 20
    @Published var asrStatus: RecognizerStatus = .stop
    @Published var asrSubtitles: String = ""
    @Published var canRecord: Bool = true
    
    // MARK: - TTS Related
    private var audioPlayer: AudioPlayer?
    private var ttsService: TTSServiceWrappeer?
    private var accumulatedText: String = ""
    private var check_next: Bool = false
    private let audioQueueManager = AudioQueueManager.shared
    private var audioStateSubscription: AnyCancellable?
    
    // MARK: - Feature Flags
    private let enableASR: Bool
    private let enableTTS: Bool
    @Published var useMmap: Bool = false
    
    // MARK: - State Management
    @Published var messages: [Message] = []
    @Published var isModelLoaded = false
    @Published var isTTSInitialized = false
    @Published var isASRInitialized = false
    @Published var isProcessing = false
    @Published var isAudioPlaying = false
    @Published var canInteract = false
    
    // MARK: - Computed Properties
    var isDiffusionModel: Bool {
        modelInfo.name.lowercased().contains("diffusion")
    }
    
    var chatInputUnavilable: Bool { !canInteract }
    
    var chatStatus: String {
        if isModelLoaded {
            return isProcessing ? "Processing..." : "Ready"
        }
        return "Model Loading..."
    }
    
    var chatCover: URL? {
        interactor.otherSenders.count == 1 ? interactor.otherSenders.first!.avatar : nil
    }
    
    // MARK: - Callbacks
    var onStreamOutput: ((String, Bool) -> Void)?
    
    // MARK: - Initialization
    init(modelInfo: ModelInfo, 
         history: ChatHistory? = nil, 
         enableASR: Bool = false, 
         enableTTS: Bool = false) {
        self.modelInfo = modelInfo
        self.history = history
        self.historyId = history?.id ?? UUID().uuidString
        self.enableASR = enableASR
        self.enableTTS = enableTTS
        
        let messages = history?.messages
        self.interactor = LLMChatInteractor(modelInfo: modelInfo, historyMessages: messages)
        self.modelConfigManager = ModelConfigManager(modelPath: modelInfo.localPath)
        self.useMmap = modelConfigManager.readUseMmap()
        
        self.isASRInitialized = !enableASR
        self.isTTSInitialized = !enableTTS
    }
    
    deinit {
        print("LLMChat View Model deinit")
    }
    
    // MARK: - Lifecycle Methods
    func onStart() {
        setupMessageSubscription()
        interactor.connect()
        
        if enableTTS { setupTTS() }
        if enableASR { initializeASR() }
        
        setupLLM(modelPath: modelInfo.localPath)
    }
    
    func onStop() {
        cleanup()
    }
    
    private func cleanup() {
        saveHistory()
        cleanupServices()
        cleanTmpFolder()
    }
    
    private func saveHistory() {
        ChatHistoryManager.shared.saveChat(
            historyId: historyId,
            modelId: modelInfo.modelId,
            modelName: modelInfo.name,
            messages: messages
        )
    }
    
    private func cleanupServices() {
        interactor.disconnect()
        llm = nil
        
        if enableTTS {
            audioPlayer?.stop()
            audioPlayer = nil
            ttsService = nil
        }
        
        if enableASR {
            stopRecorder()
            asrService = nil
        }
        
        audioQueueManager.clearQueue()
        audioStateSubscription?.cancel()
    }
    
    private func setupMessageSubscription() {
        interactor.messages
            .compactMap { $0.map { $0.toChatMessage() } }
            .assign(to: &$messages)
    }
    
    // MARK: - LLM Methods
    private func setupLLM(modelPath: String) {
        Task { @MainActor in
            sendLoadingMessage()
            isDiffusionModel ? setupDiffusionModel(modelPath) : setupLanguageModel(modelPath)
        }
    }
    
    private func setupDiffusionModel(_ modelPath: String) {
        diffusion = DiffusionSession(modelPath: modelPath) { [weak self] success in
            Task { @MainActor in
                self?.handleModelSetupCompletion(success)
            }
        }
    }
    
    private func setupLanguageModel(_ modelPath: String) {
        llm = LLMInferenceEngineWrapper(modelPath: modelPath) { [weak self] success in
            Task { @MainActor in
                self?.handleModelSetupCompletion(success)
                self?.processHistoryMessages()
            }
        }
    }
    
    private func handleModelSetupCompletion(_ success: Bool) {
        isModelLoaded = success
        sendModelLoadStatus(success: success)
        updateInteractionState()
    }
    
    private func sendLoadingMessage() {
        send(draft: DraftMessage(
            text: NSLocalizedString("ModelLoadingText", comment: ""),
            thinkText: "",
            medias: [],
            recording: nil,
            replyMessage: nil,
            createdAt: Date()
        ), userType: .system)
    }
    
    private func sendModelLoadStatus(success: Bool) {
        let loadResult = success ? 
            NSLocalizedString("ModelLoadingSuccessText", comment: "") :
            NSLocalizedString("ModelLoadingFailText", comment: "")
        
        send(draft: DraftMessage(
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
        send(draft: draft, userType: .user)
        guard isModelLoaded else { return }
        
        isDiffusionModel ? getDiffusionResponse(draft: draft) : getLLMRespsonse(draft: draft)
    }
    
    private func getDiffusionResponse(draft: DraftMessage) {
        Task {
            let tempDir = FileManager.default.temporaryDirectory
            let imageName = UUID().uuidString + ".jpg"
            let tempImagePath = tempDir.appendingPathComponent(imageName).path
            
            var lastProcess: Int32 = 0
            
            send(draft: DraftMessage(
                text: "Start Generating Image...",
                thinkText: "",
                medias: [],
                recording: nil,
                replyMessage: nil,
                createdAt: Date()
            ), userType: .assistant)
            
            let userIterations = modelConfigManager.readIterations()
            let userSeed = modelConfigManager.readSeed()
            
            diffusion?.run(
                withPrompt: draft.text,
                imagePath: tempImagePath,
                iterations: Int32(userIterations),
                seed: Int32(userSeed),
                progressCallback: { [weak self] progress in
                    guard let self = self else { return }
                    
                    if progress == 100 {
                        self.handleDiffusionComplete(tempImagePath: tempImagePath)
                    } else if ((progress - lastProcess) > 20) {
                        lastProcess = progress
                        self.updateDiffusionProgress(progress)
                    }
                }
            )
        }
    }
    
    private func handleDiffusionComplete(tempImagePath: String) {
        send(draft: DraftMessage(
            text: "Image generated successfully!",
            thinkText: "",
            medias: [],
            recording: nil,
            replyMessage: nil,
            createdAt: Date()
        ), userType: .system)
        
        interactor.sendImage(imageURL: URL(string: "file://" + tempImagePath)!)
    }
    
    private func updateDiffusionProgress(_ progress: Int32) {
        send(draft: DraftMessage(
            text: "Generating Image \(progress)%",
            thinkText: "",
            medias: [],
            recording: nil,
            replyMessage: nil,
            createdAt: Date()
        ), userType: .system)
    }
    
    private func getLLMRespsonse(draft: DraftMessage) {
        Task {
            await llmState.setProcessing(true)
            await MainActor.run {
                isProcessing = true
                updateInteractionState()
            }
            
            let content = await processMediaContent(draft)
            let convertedContent = convertDeepSeekMutliChat(content: content)
            
            await processLLMResponse(convertedContent)
        }
    }
    
    private func processMediaContent(_ draft: DraftMessage) async -> String {
        var content = draft.text
        
        // Process images
        for media in draft.medias {
            guard media.type == .image,
                  let url = await media.getURL() else { continue }
            
            if let processedUrl = await processImage(url) {
                content = "<img>\(processedUrl.path)</img>" + content
            }
        }
        
        // Process audio
        if let audio = draft.recording,
           let path = audio.url {
            content = "<audio>\(path.path)</audio>" + content
        }
        
        return content
    }
    
    private func processImage(_ url: URL) async -> URL? {
        let isInTmpDirectory = url.path.contains("/tmp/")
        let fileName = url.lastPathComponent
        
        if !isInTmpDirectory {
            guard let fileUrl = AssetExtractor.copyFileToTmpDirectory(from: url, fileName: fileName) else {
                return nil
            }
            return convertHEICImage(from: fileUrl)
        } else {
            return convertHEICImage(from: url)
        }
    }
    
    private func processLLMResponse(_ content: String) async {
        await llmState.processContent(content, llm: llm) { [weak self] output in
            Task { @MainActor in
                self?.handleLLMOutput(output)
            }
        }
    }
    
    private func handleLLMOutput(_ output: String) {
        let ended = output.contains("<eop>")
        
        if ended {
            handleEndOfResponse()
        } else {
            sendAssistantMessage(output)
        }
        
        if ttsService != nil {
            processTTS(text: output, ended: ended)
        }
    }
    
    private func handleEndOfResponse() {
        isProcessing = false
        Task {
            await llmState.setProcessing(false)
            await MainActor.run {
                updateInteractionState()
            }
        }
    }
    
    private func sendAssistantMessage(_ text: String) {
        send(draft: DraftMessage(
            text: text,
            thinkText: "",
            medias: [],
            recording: nil,
            replyMessage: nil,
            createdAt: Date()
        ), userType: .assistant)
    }
    
    func send(draft: DraftMessage, userType: UserType) {
        interactor.send(draftMessage: draft, userType: userType)
    }
    
    private func convertDeepSeekMutliChat(content: String) -> String {
        guard modelInfo.name.lowercased().contains("deepseek") else {
            return content
        }
        
        var deepSeekContent = "<|begin_of_sentence|>"
        
        for message in messages {
            let senderTag = message.user.id == "1" ? "<|User|>" : "<tbody/>"
            deepSeekContent += "\(senderTag)\(message.text)"
        }
        
        deepSeekContent += "<|end_of_sentence|><think><\n>"
        return deepSeekContent
    }
    
    func setModelConfig() {
        if let configStr = modelConfigManager.readConfigAsJSONString(),
           let llm = llm {
            llm.setConfigWithJSONString(configStr)
        }
    }
    
    // MARK: - TTS Methods
    private func setupTTS() {
        guard enableTTS else {
            isTTSInitialized = true
            updateInteractionState()
            return
        }
        
        setupAudioPlayer()
        setupTTSService()
    }
    
    private func setupAudioPlayer() {
        audioPlayer = AudioPlayer()
        audioPlayer?.onStateChanged = { [weak self] state in
            Task { @MainActor in
                self?.isAudioPlaying = state == .playing
                self?.canRecord = state != .playing
                self?.updateInteractionState()
            }
        }
    }
    
    private func setupTTSService() {
        ttsService = TTSServiceWrappeer { [weak self] success in
            Task { @MainActor in
                self?.isTTSInitialized = success
                self?.updateInteractionState()
            }
        }
        
        ttsService?.setHandler { [weak self] buffer, length, sampleRate, duration, isEOP in
            if let buffer = buffer {
                Task { @MainActor in
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
            handlePunctuation(text)
        } else if ended {
            handleEndOfText(text)
        } else {
            handleContinuousText(text)
        }
    }
    
    private func handlePunctuation(_ text: String) {
        accumulatedText += text
        check_next = true
        
        if !accumulatedText.isEmpty {
            ttsService?.play(accumulatedText, isEOP: false)
            accumulatedText = ""
        }
    }
    
    private func handleEndOfText(_ text: String) {
        let textToPlay = accumulatedText + text
        if !textToPlay.isEmpty {
            ttsService?.play(
                textToPlay.replacingOccurrences(of: "<eop>", with: ""),
                isEOP: true
            )
            accumulatedText = ""
        }
    }
    
    private func handleContinuousText(_ text: String) {
        if check_next, accumulatedText.count > 5 {
            ttsService?.play(accumulatedText, isEOP: false)
            accumulatedText = ""
        }
        check_next = false
        accumulatedText += text
    }
    
    // MARK: - ASR Methods
    private func initializeASR() {
        guard enableASR else {
            isASRInitialized = true
            updateInteractionState()
            return
        }
        
        setupASRService()
        setupASRCallbacks()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Task { @MainActor in
                self?.isASRInitialized = true
                self?.updateInteractionState()
            }
        }
    }
    
    private func setupASRService() {
        asrService = SherpaRecognizeService()
    }
    
    private func setupASRCallbacks() {
        asrService?.onTextRecognized = { [weak self] text in
            Task { @MainActor in
                guard let self = self,
                      self.lastSentence != text else { return }
                
                self.lastSentence = text
                self.updateLabel()
            }
        }
        
        asrService?.onSentenceComplete = { [weak self] text in
            Task { @MainActor in
                guard let self = self else { return }
                
                let tmp = self.lastSentence
                self.lastSentence = ""
                self.sentences.append(tmp)
                self.updateLabel()
                self.sendASRTextToLLM(text: tmp)
            }
        }
    }
    
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
        let sentencesList = sentences.enumerated().map { (index, s) in
            "\(index): \(s.lowercased())"
        }[start...]
        
        asrSubtitles = lastSentence.isEmpty ?
            sentencesList.joined(separator: "\n") :
            sentencesList.joined(separator: "\n") + "\n\(sentences.count): \(lastSentence.lowercased())"
    }
    
    func toggleRecorder() {
        guard enableASR else { return }
        
        if asrStatus == .stop {
            startRecorder()
        } else {
            stopRecorder()
        }
    }
    
    func startRecorder() {
        guard enableASR && canInteract else { return }
        
        lastSentence = ""
        sentences = []
        asrService?.startRecording()
        asrStatus = .recording
    }
    
    func stopRecorder() {
        guard enableASR else { return }
        
        asrService?.stopRecording()
        asrStatus = .stop
    }
    
    private func sendASRTextToLLM(text: String) {
        guard !text.isEmpty else { return }
        
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
    
    // MARK: - File Management Methods
    private func cleanTmpFolder() {
        let fileManager = FileManager.default
        let tmpDirectoryURL = fileManager.temporaryDirectory
        
        cleanFolder(tmpFolderURL: tmpDirectoryURL)
        
        if !useMmap {
            cleanModelTmpFolder()
        }
    }
    
    func cleanModelTmpFolder() {
        let tmpFolderURL = URL(fileURLWithPath: modelInfo.localPath)
            .appendingPathComponent("temp")
        cleanFolder(tmpFolderURL: tmpFolderURL)
    }
    
    private func cleanFolder(tmpFolderURL: URL) {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(
                at: tmpFolderURL,
                includingPropertiesForKeys: nil
            )
            
            for file in files where !file.absoluteString
                .lowercased()
                .contains("networkdownload") {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            print("Error accessing directory: \(error.localizedDescription)")
        }
    }
    
    private func convertHEICImage(from url: URL) -> URL? {
        var fileUrl = url
        if fileUrl.isHEICImage() {
            fileUrl = AssetExtractor.convertHEICToJPG(heicUrl: fileUrl) ?? url
        }
        return fileUrl
    }
    
    // MARK: - Helper Methods
    private func updateInteractionState() {
        let canInteract = isModelLoaded && 
                         isTTSInitialized && 
                         isASRInitialized && 
                         !isProcessing && 
                         !isAudioPlaying
        
        Task { @MainActor in
            self.canInteract = canInteract
            updateASRState(canInteract)
        }
    }
    
    private func updateASRState(_ canInteract: Bool) {
        guard enableASR else { return }
        
        if canInteract && asrStatus == .recording {
            startRecorder()
        } else if !canInteract && asrStatus == .recording {
            stopRecorder()
        }
    }
    
    func loadMoreMessage(before message: Message) {
        interactor.loadNextPage()
            .sink { _ in }
            .store(in: &subscriptions)
    }
}
