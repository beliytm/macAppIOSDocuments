// AudioModule.swift
// Модуль для работы с аудио
import Foundation
import SwiftUI
import Speech
import AVFoundation
import Combine

struct AudioView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var audioManager = AudioTranslationManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                if audioManager.isListening {
                    VStack(spacing: 12) {
                        HStack {
                            ProgressView()
                            Text("Слушаю...")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.pink)
                        }
                        
                        // Полный текст от микрофона
                        if !audioManager.fullRecognizedText.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Весь текст (микрофон):")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                ScrollView {
                                    Text(audioManager.fullRecognizedText)
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .padding(8)
                                }
                                .frame(maxHeight: 100)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Готовые предложения (с точками)
                        if !audioManager.completedSentences.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Готовые предложения (\(audioManager.completedSentences.count)):")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.green)
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(audioManager.completedSentences.enumerated()), id: \.offset) { index, sentence in
                                            HStack(alignment: .top, spacing: 6) {
                                                Text("\(index + 1).")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.green)
                                                
                                                Text(sentence)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .padding(8)
                                }
                                .frame(maxHeight: 250)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(6)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Статистика
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(audioManager.fullRecognizedText.split(separator: " ").count)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.blue)
                                Text("всего слов")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            
                            VStack {
                                Text("\(audioManager.completedSentences.count)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.green)
                                Text("предложений")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    Text("Нажмите кнопку\nдля начала")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button(action: {
                    if audioManager.isListening {
                        audioManager.stopListening()
                    } else {
                        audioManager.startListening()
                    }
                }) {
                    Text(audioManager.isListening ? "ОСТАНОВИТЬ" : "ПРОСЛУШАТЬ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(audioManager.isListening ? Color.red : Color.pink)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Распознавание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        audioManager.stopListening()
                        dismiss()
                    }
                }
            }
            .onAppear {
                audioManager.requestPermissions()
            }
        }
    }
}

class AudioTranslationManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var isListening = false
    @Published var fullRecognizedText = ""
    @Published var completedSentences: [String] = []
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var lastRecognizedLength = 0
    private var analysisTimer: Timer?
    private var lastAnalyzedLength = 0
    
    private let sentenceMarkers = ["yes", "yeah", "so", "then", "next", "also", "but", "however", "and", "or"]
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
    
    func startListening() {
        print("🎬 START")
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        lastRecognizedLength = 0
        lastAnalyzedLength = 0
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio session error")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let newText = result.bestTranscription.formattedString
                let newLength = newText.count
                let diff = newLength - self.lastRecognizedLength
                
                if diff != 0 {
                    if diff > 0 {
                        let added = String(newText.suffix(diff))
                        print("➕ [MIC] +\(diff): '\(added)' | Total: \(newLength)")
                    } else {
                        print("➖ [MIC] \(diff) | Total: \(newLength)")
                    }
                    
                    self.lastRecognizedLength = newLength
                    
                    DispatchQueue.main.async {
                        // ПОТОК 1: Просто пишем весь текст
                        self.fullRecognizedText = newText
                    }
                }
            }
            
            if let error = error {
                let code = (error as NSError).code
                if self.isListening && code != 216 && code != 1110 {
                    print("⚠️ Error \(code), restarting...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if self.isListening {
                            self.restartRecognition()
                        }
                    }
                }
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
                self.startAnalysis()
            }
        } catch {
            print("❌ Engine start error")
            return
        }
    }
    
    // ПОТОК 2: Анализатор (каждые 0.5 сек)
    private func startAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.analyzeText()
        }
        print("🔍 Analysis started")
    }
    
    private func analyzeText() {
        let currentLength = fullRecognizedText.count
        
        // Есть новый текст для анализа?
        guard currentLength > lastAnalyzedLength else { return }
        
        // Берём ТОЛЬКО новую часть текста
        let newPart = String(fullRecognizedText.suffix(currentLength - lastAnalyzedLength))
        print("🔍 [ANALYZE] New part (\(newPart.count) chars): '\(newPart)'")
        
        // Анализируем весь накопленный текст
        let unprocessedText = String(fullRecognizedText.suffix(currentLength - lastAnalyzedLength))
        let words = unprocessedText.split(separator: " ")
        let wordCount = words.count
        
        print("🔍 [ANALYZE] Unprocessed: \(wordCount) words")
        
        // ТРИГГЕР 1: 15 слов
        if wordCount >= 15 {
            print("📏 [ANALYZE] 15 words → SAVE")
            extractSentence(wordCount: 15)
            return
        }
        
        // ТРИГГЕР 2: Маркер + 5 слов
        if wordCount >= 5 {
            let lastWord = words.last?.lowercased() ?? ""
            if sentenceMarkers.contains(lastWord) {
                print("🔑 [ANALYZE] Marker '\(lastWord)' → SAVE")
                extractSentence(wordCount: wordCount)
                return
            }
        }
    }
    
    private func extractSentence(wordCount: Int) {
        let unprocessedText = String(fullRecognizedText.suffix(fullRecognizedText.count - lastAnalyzedLength))
        let words = unprocessedText.split(separator: " ")
        
        let sentenceWords = words.prefix(wordCount)
        let sentence = sentenceWords.joined(separator: " ") + "."
        
        let charsProcessed = sentenceWords.joined(separator: " ").count
        
        DispatchQueue.main.async {
            self.completedSentences.append(sentence)
            self.lastAnalyzedLength += charsProcessed + 1 // +1 for space
            
            print("✅ [SAVE] '\(sentence)'")
            print("📦 Total: \(self.completedSentences.count) sentences")
            print("📍 Analyzed up to position: \(self.lastAnalyzedLength)")
        }
    }
    
    private func restartRecognition() {
        print("🔄 RESTART")
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = self.recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false
            
            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    let newText = result.bestTranscription.formattedString
                    let newLength = newText.count
                    let diff = newLength - self.lastRecognizedLength
                    
                    if diff != 0 {
                        if diff > 0 {
                            let added = String(newText.suffix(diff))
                            print("➕ [MIC] +\(diff): '\(added)' | Total: \(newLength)")
                        } else {
                            print("➖ [MIC] \(diff) | Total: \(newLength)")
                        }
                        
                        self.lastRecognizedLength = newLength
                        
                        DispatchQueue.main.async {
                            self.fullRecognizedText = newText
                        }
                    }
                }
                
                if let error = error {
                    let code = (error as NSError).code
                    if self.isListening && code != 216 && code != 1110 {
                        print("⚠️ Error \(code), restarting...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if self.isListening {
                                self.restartRecognition()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func stopListening() {
        print("🛑 STOP")
        
        isListening = false
        analysisTimer?.invalidate()
        analysisTimer = nil
        
        // Сохраняем остаток
        if fullRecognizedText.count > lastAnalyzedLength {
            let remaining = String(fullRecognizedText.suffix(fullRecognizedText.count - lastAnalyzedLength))
            if !remaining.trimmingCharacters(in: .whitespaces).isEmpty {
                completedSentences.append(remaining.trimmingCharacters(in: .whitespaces) + ".")
                print("✅ [STOP] Saved remaining: '\(remaining)'")
            }
        }
        
        recognitionTask?.finish()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
        
        DispatchQueue.main.async {
            self.lastRecognizedLength = 0
            self.lastAnalyzedLength = 0
        }
    }
}
