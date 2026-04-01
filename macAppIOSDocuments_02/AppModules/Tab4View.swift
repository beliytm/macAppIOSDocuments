// Tab4Module.swift
// GPT tab module + shared UI components
import Foundation
import SwiftUI
import AVFoundation

// MARK: - Speech Manager (shared)

class SpeechManager {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    func speak(_ text: String, language: String = "en-US") {
        if !UserDefaults.standard.bool(forKey: "globalSoundEnabled_init") {
            UserDefaults.standard.set(true, forKey: "globalSoundEnabled")
            UserDefaults.standard.set(true, forKey: "globalSoundEnabled_init")
        }
        
        guard UserDefaults.standard.bool(forKey: "globalSoundEnabled") else { return }
        
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
}

// MARK: - Tab4 Module (GPT-MODULAR)

final class Tab4Module: BaseModule {
    
    init() {
        super.init(
            name: "Tab4Module",
            displayName: "GPT",
            icon: "chart.bar.fill",
            dependencies: []
        )
    }
    
    override func initialize() async throws {
        try await super.initialize()
        // Setup only - no business logic
    }
    
    override func execute() async -> ModuleResult {
        // UI module - no execute logic needed
        return .success(nil)
    }
    
    override func cleanup() {
        super.cleanup()
        // Cleanup resources if any
    }
    
    override func getView() -> AnyView {
        AnyView(Tab3View())
    }
}

// Диалоговая плашка 1 - плашка с русским словом (хвостик слева)
struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let cornerRadius: CGFloat = 18
        let tailWidth: CGFloat = 12
        let tailHeight: CGFloat = 10
        let tailOffset: CGFloat = 20
        
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 0),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tailOffset + tailHeight))
        path.addLine(to: CGPoint(x: rect.minX - tailWidth, y: rect.minY + tailOffset + (tailHeight / 2)))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tailOffset))
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: -90),
                    clockwise: false)
        
        return path
    }
}

// Диалоговая плашка 2 - плашка с правильным ответом (хвостик сверху по центру)
struct AnswerBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let cornerRadius: CGFloat = 18
        let tailWidth: CGFloat = 12
        let tailHeight: CGFloat = 10
        let centerX = rect.midX
        
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        
        path.addLine(to: CGPoint(x: centerX - (tailWidth / 2), y: rect.minY))
        path.addLine(to: CGPoint(x: centerX, y: rect.minY - tailHeight))
        path.addLine(to: CGPoint(x: centerX + (tailWidth / 2), y: rect.minY))
        
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 0),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: -90),
                    clockwise: false)
        
        return path
    }
}

// Форма выделения маркером с эффектом кисти
struct HighlightBrushShape: Shape {
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width * progress
        let height = rect.height
        
        // Параметры для неровностей
        let leftStart: CGFloat = -6
        let rightEnd: CGFloat = 8
        
        // Верхняя линия с неровностями
        path.move(to: CGPoint(x: leftStart - 2, y: height * 0.3))
        
        path.addCurve(
            to: CGPoint(x: width * 0.2, y: height * 0.15),
            control1: CGPoint(x: width * 0.05, y: height * 0.25),
            control2: CGPoint(x: width * 0.15, y: height * 0.1)
        )
        
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.2),
            control1: CGPoint(x: width * 0.3, y: height * 0.18),
            control2: CGPoint(x: width * 0.4, y: height * 0.25)
        )
        
        path.addCurve(
            to: CGPoint(x: width * 0.8, y: height * 0.1),
            control1: CGPoint(x: width * 0.6, y: height * 0.15),
            control2: CGPoint(x: width * 0.7, y: height * 0.08)
        )
        
        path.addCurve(
            to: CGPoint(x: width + rightEnd, y: height * 0.2),
            control1: CGPoint(x: width * 0.9, y: height * 0.12),
            control2: CGPoint(x: width + 2, y: height * 0.18)
        )
        
        // Правая сторона
        path.addLine(to: CGPoint(x: width + rightEnd - 1, y: height * 0.85))
        
        // Нижняя линия с неровностями
        path.addCurve(
            to: CGPoint(x: width * 0.7, y: height * 0.9),
            control1: CGPoint(x: width * 0.9, y: height * 0.88),
            control2: CGPoint(x: width * 0.8, y: height * 0.92)
        )
        
        path.addCurve(
            to: CGPoint(x: width * 0.4, y: height * 0.85),
            control1: CGPoint(x: width * 0.6, y: height * 0.88),
            control2: CGPoint(x: width * 0.5, y: height * 0.82)
        )
        
        path.addCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.9),
            control1: CGPoint(x: width * 0.3, y: height * 0.88),
            control2: CGPoint(x: width * 0.2, y: height * 0.92)
        )
        
        path.addCurve(
            to: CGPoint(x: leftStart, y: height * 0.8),
            control1: CGPoint(x: width * 0.05, y: height * 0.88),
            control2: CGPoint(x: leftStart + 2, y: height * 0.85)
        )
        
        path.closeSubpath()
        
        return path
    }
}
