// Tab3View.swift
// GPT translation view
import Foundation
import SwiftUI

struct Tab3View: View {
    @KeychainStorage("gptApiKey") private var apiKey: String
    @State private var tempKey: String = ""
    @State private var isChecking: Bool = false
    @State private var keyStatus: String = ""
    @State private var statusColor: Color = .gray
    @State private var userInput: String = ""
    @State private var translatedText: String = ""
    @State private var isTranslating: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var translationHistory: [(text: String, translation: String, timestamp: Date)] = []
    @FocusState private var isTempKeyFocused: Bool
    @State private var buttonPressed: Bool = false
    @State private var showingAudioView = false
    

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isInputFocused = false
                        isTempKeyFocused = false
                    }
                
                VStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("API Key")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        HStack {
                            if tempKey.isEmpty && !apiKey.isEmpty {
                                Text("••••••••" + String(apiKey.suffix(4)))
                                    .font(.system(size: 17, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        tempKey = apiKey
                                    }
                            } else {
                                TextField("Введите API ключ", text: $tempKey)
                                    .font(.system(size: 17, design: .rounded))
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .focused($isTempKeyFocused)
                            }
                            
                            if !tempKey.isEmpty {
                                Button(action: {
                                    saveAndCheckKey()
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.pink)
                                        .font(.system(size: 24))
                                }
                            }
                            
                            if !apiKey.isEmpty {
                                Image(systemName: statusColor == .green ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(statusColor)
                                    .font(.system(size: 24))
                            }
                        }
                        .padding(.horizontal)
                        
                        if isChecking {
                            HStack {
                                ProgressView()
                                    .padding(.leading)
                                Text("Проверка ключа...")
                                    .foregroundColor(.gray)
                                    .font(.system(.caption, design: .rounded))
                            }
                        } else if !keyStatus.isEmpty {
                            Text(keyStatus)
                                .foregroundColor(statusColor)
                                .font(.system(.caption, design: .rounded))
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(translationHistory.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 0) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        
                                        let maxWidth = UIScreen.main.bounds.width - 92
                                        let needsWrapping = shouldWrapText(translationHistory[index].text, maxWidth: maxWidth)
                                        
                                        ZStack(alignment: .leading) {
                                            SpeechBubbleShape()
                                                .fill(Color.white)
                                            
                                            SpeechBubbleShape()
                                                .stroke(Color(hex: "e5e5ea"), lineWidth: 2)
                                            
                                            if needsWrapping {
                                                Text(translationHistory[index].text)
                                                    .font(.system(size: 16, design: .rounded))
                                                    .foregroundColor(.black)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(maxWidth: maxWidth, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .padding(16)
                                            } else {
                                                Text(translationHistory[index].text)
                                                    .font(.system(size: 16, design: .rounded))
                                                    .foregroundColor(.black)
                                                    .multilineTextAlignment(.leading)
                                                    .padding(16)
                                            }
                                        }
                                        .fixedSize(horizontal: !needsWrapping, vertical: true)
                                        
                                        HStack(spacing: 4) {
                                            let maxWidth = UIScreen.main.bounds.width - 172
                                            let needsWrapping = shouldWrapText(translationHistory[index].translation, maxWidth: maxWidth)
                                            
                                            ZStack(alignment: .leading) {
                                                SpeechBubbleShape()
                                                    .fill(Color(hex: "f7f7f7"))
                                                
                                                SpeechBubbleShape()
                                                    .stroke(Color(hex: "e5e5ea"), lineWidth: 2)
                                                
                                                if needsWrapping {
                                                    Text(translationHistory[index].translation)
                                                        .font(.system(size: 16, design: .rounded))
                                                        .foregroundColor(.black)
                                                        .multilineTextAlignment(.leading)
                                                        .frame(maxWidth: maxWidth, alignment: .leading)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                        .padding(16)
                                                } else {
                                                    Text(translationHistory[index].translation)
                                                        .font(.system(size: 16, design: .rounded))
                                                        .foregroundColor(.black)
                                                        .multilineTextAlignment(.leading)
                                                        .padding(16)
                                                }
                                            }
                                            .fixedSize(horizontal: !needsWrapping, vertical: true)
                                            
                                            HStack(spacing: 4) {
                                                Button(action: {
                                                    UIPasteboard.general.string = translationHistory[index].translation
                                                }) {
                                                    Image(systemName: "doc.on.doc")
                                                        .foregroundColor(.pink)
                                                        .font(.system(size: 20))
                                                        .padding(8)
                                                }
                                                
                                                Button(action: {
                                                    speakText(translationHistory[index].translation)
                                                }) {
                                                    Image(systemName: "speaker.wave.2.fill")
                                                        .foregroundColor(.pink)
                                                        .font(.system(size: 20))
                                                        .padding(8)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    Spacer()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("", text: $userInput)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($isInputFocused)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    ZStack {
                        if !userInput.isEmpty && !buttonPressed {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "c9618a"))
                                .frame(height: 56)
                                .offset(y: 4)
                        }
                        
                        HStack {
                            if isTranslating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isTranslating ? "Перевод..." : "ПЕРЕВЕСТИ")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((userInput.isEmpty || apiKey.isEmpty || isTranslating) ? Color.gray : Color.pink)
                        .cornerRadius(12)
                        .offset(y: buttonPressed ? 4 : 0)
                        .onTapGesture {
                            guard !userInput.isEmpty && !apiKey.isEmpty && !isTranslating else { return }
                            buttonPressed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                buttonPressed = false
                            }
                            translateText()
                            isInputFocused = false
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("GPT")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAudioView = true
                    }) {
                        Image(systemName: "waveform")
                    }
                }
            }
            .sheet(isPresented: $showingAudioView) {
                AudioView()
            }
            .onAppear {
                tempKey = apiKey
                if !apiKey.isEmpty {
                    checkApiKey(apiKey)
                }
            }
        }
    }
    
    private func saveAndCheckKey() {
        apiKey = tempKey
        checkApiKey(tempKey)
        tempKey = ""
    }
    
    private func textWidth(text: String, font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return size.width + 32 // +32 для padding
    }
    
    private func shouldWrapText(_ text: String, maxWidth: CGFloat) -> Bool {
        let font = UIFont.systemFont(ofSize: 16, weight: .regular)
        return textWidth(text: text, font: font) > maxWidth
    }
    
    private func checkApiKey(_ key: String) {
        guard !key.isEmpty else { return }
        
        isChecking = true
        keyStatus = ""
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isChecking = false
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        keyStatus = "✓ Ключ рабочий"
                        statusColor = .green
                    } else {
                        keyStatus = "✗ Ключ недействителен"
                        statusColor = .red
                    }
                } else {
                    keyStatus = "✗ Ошибка проверки"
                    statusColor = .red
                }
            }
        }.resume()
    }
    
    private func translateText() {
            guard !apiKey.isEmpty, !userInput.isEmpty else { return }
            
            isTranslating = true
            
            cleanOldTranslations()
            
            let prompt = """
            Translate the following text. If it's in Russian, translate to English. If it's in English, translate to Russian. Return ONLY the translation, nothing else:
            
            \(userInput)
            """
            
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "model": "gpt-3.5-turbo",
                "messages": [
                    ["role": "user", "content": prompt]
                ],
                "max_tokens": 200
            ]
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            let inputText = userInput
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    isTranslating = false
                    
                    guard let data = data else {
                        return
                    }
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        let translation = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        translationHistory.append((text: inputText, translation: translation, timestamp: Date()))
                        userInput = ""
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1800) {
                            cleanOldTranslations()
                        }
                    }
                }
            }.resume()
        }
        
        private func speakText(_ text: String) {
            // Определяем язык для правильного произношения
            let language: String
            if text.range(of: "[а-яА-ЯёЁ]", options: .regularExpression) != nil {
                language = "ru-RU"
            } else {
                language = "en-US"
            }
            
            SpeechManager.shared.speak(text, language: language)
        }
        
        private func cleanOldTranslations() {
            let currentTime = Date()
            translationHistory.removeAll { item in
                currentTime.timeIntervalSince(item.timestamp) > 1800
            }
        }
}
