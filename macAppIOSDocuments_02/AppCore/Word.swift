// Word.swift
import Foundation

struct Word: Identifiable, Codable {
    var id = UUID()
    var english: String
    var russian: String
    var isHidden: Bool
    
    init(id: UUID = UUID(), english: String, russian: String, isHidden: Bool = false) {
        self.id = id
        self.english = english
        self.russian = russian
        self.isHidden = isHidden
    }
}
