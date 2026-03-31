// Word.swift
// Модель для хранения слова (английский + русский)
import Foundation
import SwiftUI
import Combine

class WordStorage: ObservableObject {
    static let shared = WordStorage()
    
    @Published var words: [Word] = []
    
    private let saveKey = "SavedWords"
    
    private init() {
        loadWords()
    }
    
    func addWord(english: String, russian: String) {
        let word = Word(english: english, russian: russian, isHidden: false)
        words.insert(word, at: 0)
        saveWords()
    }
    
    func deleteWord(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
        saveWords()
    }
    
    func hideWord(at offsets: IndexSet) {
        for index in offsets {
            words[index].isHidden = true
        }
        saveWords()
    }
    
    func unhideWord(at offsets: IndexSet) {
        for index in offsets {
            words[index].isHidden = false
        }
        saveWords()
    }
    
    private func saveWords() {
        if let encoded = try? JSONEncoder().encode(words) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadWords() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Word].self, from: data) {
            words = decoded
        }
    }
}
