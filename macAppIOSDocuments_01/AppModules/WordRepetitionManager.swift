// WordRepetitionManager.swift
// Продвинутая система интервальных повторений с анализом забывания, времени ответа и усталости
import Foundation
import SwiftUI
import Combine

struct WordStatistics: Codable {
    var wordId: UUID
    var correctAnswers: Int
    var wrongAnswers: Int
    var lastReviewDate: Date
    var nextReviewDate: Date
    var easeFactor: Double // от 1.3 до 2.5
    var interval: TimeInterval // в секундах
    var repetitionNumber: Int
    var difficultyLevel: Double // от 0.0 (легкое) до 1.0 (сложное)
    var reviewHistory: [ReviewRecord] // история всех повторений
    var averageResponseTime: TimeInterval // среднее время ответа
    var lastResponseTime: TimeInterval // последнее время ответа
    var consecutiveCorrect: Int // подряд правильных ответов
    var consecutiveWrong: Int // подряд неправильных ответов
    var forgettingCurve: Double // коэффициент забывания (0.0 - 1.0)
    
    init(wordId: UUID) {
        self.wordId = wordId
        self.correctAnswers = 0
        self.wrongAnswers = 0
        self.lastReviewDate = Date()
        self.nextReviewDate = Date()
        self.easeFactor = 2.5
        self.interval = 0
        self.repetitionNumber = 0
        self.difficultyLevel = 0.5
        self.reviewHistory = []
        self.averageResponseTime = 0
        self.lastResponseTime = 0
        self.consecutiveCorrect = 0
        self.consecutiveWrong = 0
        self.forgettingCurve = 0.3
    }
}

struct ReviewRecord: Codable {
    var date: Date
    var wasCorrect: Bool
    var responseTime: TimeInterval
    var timeSinceLastReview: TimeInterval
}

class WordRepetitionManager: ObservableObject {
    
    
    static let shared = WordRepetitionManager()
    
    @Published var statistics: [UUID: WordStatistics] = [:]
    @Published var sessionStartTime: Date = Date()
    @Published var sessionErrorCount: Int = 0
    @Published var sessionCorrectCount: Int = 0
    
    private let saveKey = "WordStatistics"
    
    // Параметры для определения усталости
    private let fatigueThreshold = 5 // ошибок подряд
    private let sessionDurationForFatigue: TimeInterval = 1800 // 30 минут
    
    // Логирование для отладки
    private var logsEnabled = false
    
    private func log(_ message: String) {
        if logsEnabled {
            print("📊 [WordRepetition] \(message)")
        }
    }
    
    private init() {
        loadStatistics()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // Включить/выключить логи
    func setLogging(enabled: Bool) {
        logsEnabled = enabled
    }
    
    // Получить детальную статистику по слову для отладки
    func getDetailedLog(for wordId: UUID) -> String {
        guard let stat = statistics[wordId] else {
            return "Слово не найдено"
        }
        
        var log = """
        
        📖 ДЕТАЛЬНАЯ СТАТИСТИКА
        ═══════════════════════
        Правильных: \(stat.correctAnswers)
        Неправильных: \(stat.wrongAnswers)
        Подряд правильных: \(stat.consecutiveCorrect)
        Подряд ошибок: \(stat.consecutiveWrong)
        
        easeFactor: \(String(format: "%.2f", stat.easeFactor))
        Сложность: \(String(format: "%.2f", stat.difficultyLevel))
        Кривая забывания: \(String(format: "%.2f", stat.forgettingCurve))
        
        Интервал: \(String(format: "%.1f", stat.interval/3600))ч
        Повторение №: \(stat.repetitionNumber)
        
        Среднее время ответа: \(String(format: "%.1f", stat.averageResponseTime))s
        Последнее время: \(String(format: "%.1f", stat.lastResponseTime))s
        
        ИСТОРИЯ (последние 10):
        """
        
        for record in stat.reviewHistory.suffix(10) {
            let icon = record.wasCorrect ? "✅" : "❌"
            log += "\n\(icon) \(formatDate(record.date)) | \(String(format: "%.1f", record.responseTime))s"
        }
        
        return log
    }
    
    // Регистрация правильного ответа с временем
    func recordCorrectAnswer(for wordId: UUID, responseTime: TimeInterval = 3.0) {
        var stat = statistics[wordId] ?? WordStatistics(wordId: wordId)
        
        let timeSinceLastReview = Date().timeIntervalSince(stat.lastReviewDate)
        
        // Добавляем в историю
        let record = ReviewRecord(
            date: Date(),
            wasCorrect: true,
            responseTime: responseTime,
            timeSinceLastReview: timeSinceLastReview
        )
        stat.reviewHistory.append(record)
        if stat.reviewHistory.count > 50 {
            stat.reviewHistory.removeFirst()
        }
        
        stat.correctAnswers += 1
        stat.consecutiveCorrect += 1
        stat.consecutiveWrong = 0
        stat.repetitionNumber += 1
        stat.lastReviewDate = Date()
        stat.lastResponseTime = responseTime
        
        log("✅ Правильный ответ | Слово ID: \(wordId.uuidString.prefix(8)) | Время ответа: \(String(format: "%.1f", responseTime))s | Подряд правильных: \(stat.consecutiveCorrect)")
        
        // Обновляем среднее время ответа
        updateAverageResponseTime(&stat, newTime: responseTime)
        
        // Анализируем скорость ответа
        let speedFactor = analyzeResponseSpeed(responseTime: responseTime, average: stat.averageResponseTime)
        
        log("   Среднее время: \(String(format: "%.1f", stat.averageResponseTime))s | Скорость: \(String(format: "%.2f", speedFactor))x")
        
        // Обновляем уровень сложности
        updateDifficultyLevel(&stat, wasCorrect: true, speedFactor: speedFactor)
        
        // Увеличиваем easeFactor с учетом скорости ответа
        let easeBonus = speedFactor > 1.2 ? 0.15 : (speedFactor > 1.0 ? 0.1 : 0.05)
        stat.easeFactor = min(stat.easeFactor + easeBonus, 2.5)
        
        // Обновляем кривую забывания
        updateForgettingCurve(&stat, wasCorrect: true, timeSinceLastReview: timeSinceLastReview)
        
        log("   Сложность: \(String(format: "%.2f", stat.difficultyLevel)) | easeFactor: \(String(format: "%.2f", stat.easeFactor)) | Кривая забывания: \(String(format: "%.2f", stat.forgettingCurve))")
        
        // Рассчитываем новый интервал с учетом всех факторов
        stat.interval = calculateAdvancedInterval(
            stat: stat,
            wasCorrect: true,
            speedFactor: speedFactor
        )
        
        stat.nextReviewDate = Date().addingTimeInterval(stat.interval)
        
        let hours = stat.interval / 3600
        log("   Новый интервал: \(String(format: "%.1f", hours))ч | Следующее повторение: \(formatDate(stat.nextReviewDate))\n")
        
        statistics[wordId] = stat
        sessionCorrectCount += 1
        saveStatistics()
    }
    
    // Регистрация неправильного ответа с временем
    func recordWrongAnswer(for wordId: UUID, responseTime: TimeInterval = 5.0) {
        var stat = statistics[wordId] ?? WordStatistics(wordId: wordId)
        
        let timeSinceLastReview = Date().timeIntervalSince(stat.lastReviewDate)
        
        // Добавляем в историю
        let record = ReviewRecord(
            date: Date(),
            wasCorrect: false,
            responseTime: responseTime,
            timeSinceLastReview: timeSinceLastReview
        )
        stat.reviewHistory.append(record)
        if stat.reviewHistory.count > 50 {
            stat.reviewHistory.removeFirst()
        }
        
        stat.wrongAnswers += 1
        stat.consecutiveWrong += 1
        stat.consecutiveCorrect = 0
        stat.lastReviewDate = Date()
        stat.lastResponseTime = responseTime
        
        log("❌ Неправильный ответ | Слово ID: \(wordId.uuidString.prefix(8)) | Время ответа: \(String(format: "%.1f", responseTime))s | Подряд ошибок: \(stat.consecutiveWrong)")
        
        // Обновляем среднее время ответа
        updateAverageResponseTime(&stat, newTime: responseTime)
        
        // Обновляем уровень сложности (повышаем при ошибке)
        updateDifficultyLevel(&stat, wasCorrect: false, speedFactor: 0.5)
        
        // Обновляем кривую забывания
        updateForgettingCurve(&stat, wasCorrect: false, timeSinceLastReview: timeSinceLastReview)
        
        // Проверяем усталость пользователя
        let isFatigued = checkUserFatigue()
        
        // Анализируем контекст ошибки
        let errorContext = analyzeErrorContext(stat: stat, isFatigued: isFatigued)
        
        let totalAnswers = stat.correctAnswers + stat.wrongAnswers
        let successRate = totalAnswers > 0 ? Double(stat.correctAnswers) / Double(totalAnswers) : 0.0
        
        log("   Контекст ошибки: \(errorContext) | Усталость: \(isFatigued) | Успех: \(String(format: "%.0f", successRate * 100))%")
        log("   Сложность: \(String(format: "%.2f", stat.difficultyLevel)) | easeFactor: \(String(format: "%.2f", stat.easeFactor))")
        
        // Рассчитываем наказание в зависимости от контекста
        applyPenalty(&stat, context: errorContext, isFatigued: isFatigued)
        
        stat.nextReviewDate = Date().addingTimeInterval(stat.interval)
        
        let minutes = stat.interval / 60
        log("   Новый интервал: \(String(format: "%.0f", minutes))мин | Следующее повторение: \(formatDate(stat.nextReviewDate))\n")
        
        statistics[wordId] = stat
        sessionErrorCount += 1
        saveStatistics()
    }
    
    // Анализ скорости ответа (speedFactor > 1.0 = быстро, < 1.0 = медленно)
    private func analyzeResponseSpeed(responseTime: TimeInterval, average: TimeInterval) -> Double {
        if average == 0 { return 1.0 }
        let ratio = average / responseTime
        return min(max(ratio, 0.5), 2.0)
    }
    
    // Обновление среднего времени ответа
    private func updateAverageResponseTime(_ stat: inout WordStatistics, newTime: TimeInterval) {
        if stat.averageResponseTime == 0 {
            stat.averageResponseTime = newTime
        } else {
            stat.averageResponseTime = (stat.averageResponseTime * 0.7) + (newTime * 0.3)
        }
    }
    
    // Обновление уровня сложности слова
    private func updateDifficultyLevel(_ stat: inout WordStatistics, wasCorrect: Bool, speedFactor: Double) {
        if wasCorrect {
            let reduction = speedFactor > 1.2 ? 0.1 : 0.05
            stat.difficultyLevel = max(stat.difficultyLevel - reduction, 0.0)
        } else {
            stat.difficultyLevel = min(stat.difficultyLevel + 0.15, 1.0)
        }
    }
    
    // Обновление кривой забывания
    private func updateForgettingCurve(_ stat: inout WordStatistics, wasCorrect: Bool, timeSinceLastReview: TimeInterval) {
        let expectedInterval = stat.interval > 0 ? stat.interval : 600.0
        let overdueRatio = timeSinceLastReview / expectedInterval
        
        if wasCorrect {
            if overdueRatio > 2.0 {
                // Ответил правильно, хотя сильно просрочено - медленное забывание
                stat.forgettingCurve = max(stat.forgettingCurve - 0.1, 0.1)
            } else {
                stat.forgettingCurve = max(stat.forgettingCurve - 0.05, 0.1)
            }
        } else {
            if overdueRatio > 1.5 {
                // Ошибка из-за долгого ожидания - быстрое забывание
                stat.forgettingCurve = min(stat.forgettingCurve + 0.2, 1.0)
            } else {
                stat.forgettingCurve = min(stat.forgettingCurve + 0.1, 1.0)
            }
        }
    }
    
    // Продвинутый расчет интервала
    private func calculateAdvancedInterval(stat: WordStatistics, wasCorrect: Bool, speedFactor: Double) -> TimeInterval {
        let baseInterval: TimeInterval
        
        switch stat.repetitionNumber {
        case 1:
            baseInterval = 600 // 10 минут
        case 2:
            baseInterval = 3600 // 1 час
        case 3:
            baseInterval = 10800 // 3 часа
        case 4:
            baseInterval = 86400 // 1 день
        default:
            baseInterval = stat.interval * stat.easeFactor
        }
        
        // Корректируем интервал с учетом сложности
        var adjustedInterval = baseInterval * (1.0 - stat.difficultyLevel * 0.3)
        
        // Корректируем с учетом кривой забывания
        adjustedInterval = adjustedInterval * (1.0 - stat.forgettingCurve * 0.2)
        
        // Корректируем с учетом скорости ответа (только для правильных)
        if wasCorrect && speedFactor > 1.0 {
            adjustedInterval = adjustedInterval * (1.0 + (speedFactor - 1.0) * 0.5)
        }
        
        // Бонус за серию правильных ответов
        if stat.consecutiveCorrect >= 5 {
            adjustedInterval = adjustedInterval * 1.2
        }
        
        return max(adjustedInterval, 300) // минимум 5 минут
    }
    
    // Проверка усталости пользователя
    private func checkUserFatigue() -> Bool {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        
        log("⏱️ Проверка усталости | Ошибок: \(sessionErrorCount) | Правильных: \(sessionCorrectCount) | Время сессии: \(String(format: "%.0f", sessionDuration/60))мин")
        
        // Усталость если много ошибок подряд
        if sessionErrorCount >= fatigueThreshold && sessionCorrectCount < sessionErrorCount {
            return true
        }
        
        // Усталость если долгая сессия и низкий процент правильных
        if sessionDuration > sessionDurationForFatigue {
            let totalAnswers = sessionCorrectCount + sessionErrorCount
            if totalAnswers > 0 {
                let successRate = Double(sessionCorrectCount) / Double(totalAnswers)
                if successRate < 0.5 {
                    return true
                }
            }
        }
        
        return false
    }
    
    // Анализ контекста ошибки
    private func analyzeErrorContext(stat: WordStatistics, isFatigued: Bool) -> ErrorContext {
        let totalAnswers = stat.correctAnswers + stat.wrongAnswers
        let successRate = totalAnswers > 0 ? Double(stat.correctAnswers) / Double(totalAnswers) : 0.0
        
        // Анализируем недавнюю историю (последние 5 повторений)
        let recentHistory = stat.reviewHistory.suffix(5)
        let recentCorrect = recentHistory.filter { $0.wasCorrect }.count
        let recentSuccessRate = recentHistory.count > 0 ? Double(recentCorrect) / Double(recentHistory.count) : 0.0
        
        if isFatigued {
            return .fatigue
        } else if stat.consecutiveWrong >= 3 {
            return .struggling
        } else if successRate >= 0.85 && stat.correctAnswers >= 10 {
            return .expertSlip // эксперт оступился
        } else if recentSuccessRate >= 0.8 && stat.correctAnswers >= 5 {
            return .temporaryLapse // временная ошибка
        } else if stat.difficultyLevel > 0.7 {
            return .difficultWord // сложное слово
        } else if totalAnswers <= 3 {
            return .earlyLearning // начальное изучение
        } else {
            return .normalError // обычная ошибка
        }
    }
    
    // Применение наказания в зависимости от контекста
    private func applyPenalty(_ stat: inout WordStatistics, context: ErrorContext, isFatigued: Bool) {
        switch context {
        case .expertSlip:
            // Очень легкое наказание для экспертов
            stat.easeFactor = max(stat.easeFactor - 0.05, 1.3)
            stat.interval = max(stat.interval / 1.5, 7200) // минимум 2 часа
            stat.repetitionNumber = max(stat.repetitionNumber - 1, 3)
            
        case .temporaryLapse:
            // Легкое наказание для временной ошибки
            stat.easeFactor = max(stat.easeFactor - 0.1, 1.3)
            stat.interval = max(stat.interval / 2.0, 3600) // минимум 1 час
            stat.repetitionNumber = max(stat.repetitionNumber - 1, 2)
            
        case .fatigue:
            // Не наказываем сильно за усталость
            stat.easeFactor = max(stat.easeFactor - 0.05, 1.3)
            stat.interval = 3600 // 1 час отдыха
            
        case .struggling:
            // Среднее наказание за серию ошибок
            stat.easeFactor = max(stat.easeFactor - 0.2, 1.3)
            stat.interval = 600 // 10 минут
            stat.repetitionNumber = 0
            
        case .difficultWord:
            // Учитываем что слово сложное
            stat.easeFactor = max(stat.easeFactor - 0.15, 1.3)
            stat.interval = 900 // 15 минут
            stat.repetitionNumber = max(stat.repetitionNumber - 2, 0)
            
        case .earlyLearning:
            // Мягкое наказание на начальном этапе
            stat.easeFactor = max(stat.easeFactor - 0.1, 1.3)
            stat.interval = 600 // 10 минут
            
        case .normalError:
            // Стандартное наказание
            stat.easeFactor = max(stat.easeFactor - 0.15, 1.3)
            stat.interval = 1200 // 20 минут
            stat.repetitionNumber = max(stat.repetitionNumber - 1, 0)
        }
    }
    
    // Получить приоритетные слова для игры с учетом продвинутой логики
    func getWeightedWordsForGame(from allWords: [Word], count: Int) -> [Word] {
        let availableWords = allWords.filter { !$0.isHidden }
        guard !availableWords.isEmpty else { return [] }
        
        var weightedWords: [(word: Word, weight: Double)] = []
        let now = Date()
        
        log("🎮 Выбор слов для игры (нужно \(count))")
        
        for word in availableWords {
            if let stat = statistics[word.id] {
                var weight = 1.0
                
                // Вес зависит от времени до следующего повторения
                let timeUntilReview = stat.nextReviewDate.timeIntervalSince(now)
                let overdueTime = -timeUntilReview
                
                if timeUntilReview <= 0 {
                    // Просроченные слова - вес зависит от того, насколько просрочено
                    if overdueTime > 86400 { // больше суток
                        weight = 15.0
                    } else if overdueTime > 43200 { // больше 12 часов
                        weight = 12.0
                    } else if overdueTime > 3600 { // больше часа
                        weight = 10.0
                    } else {
                        weight = 8.0
                    }
                    
                    // Увеличиваем вес с учетом кривой забывания
                    weight *= (1.0 + stat.forgettingCurve)
                    
                } else if timeUntilReview <= 3600 {
                    weight = 5.0
                } else if timeUntilReview <= 86400 {
                    weight = 2.0
                } else {
                    weight = 0.5
                }
                
                // Увеличиваем вес для сложных слов
                weight *= (1.0 + stat.difficultyLevel * 0.5)
                
                // Увеличиваем вес для слов с большим количеством ошибок
                if stat.wrongAnswers > stat.correctAnswers {
                    weight *= 2.0
                }
                
                // Увеличиваем вес для слов с низким процентом правильных
                let totalAnswers = stat.correctAnswers + stat.wrongAnswers
                if totalAnswers > 0 {
                    let successRate = Double(stat.correctAnswers) / Double(totalAnswers)
                    if successRate < 0.5 {
                        weight *= 1.8
                    }
                }
                
                // Снижаем вес для слов, которые хорошо знаем
                if stat.consecutiveCorrect >= 5 && stat.easeFactor >= 2.3 {
                    weight *= 0.3
                }
                
                let status = timeUntilReview <= 0 ? "ПРОСРОЧЕНО" : "через \(String(format: "%.0f", timeUntilReview/3600))ч"
                log("   Слово ID: \(word.id.uuidString.prefix(8)) | Вес: \(String(format: "%.1f", weight)) | \(status) | Сложность: \(String(format: "%.2f", stat.difficultyLevel))")
                
                weightedWords.append((word, weight))
            } else {
                // Новые слова - высокий приоритет
                log("   Слово ID: \(word.id.uuidString.prefix(8)) | Вес: 4.0 | НОВОЕ")
                weightedWords.append((word, 4.0))
            }
        }
        
        // Выбираем слова с учетом весов
        var selectedWords: [Word] = []
        var remainingWords = weightedWords
        
        for _ in 0..<min(count, availableWords.count) {
            let totalWeight = remainingWords.reduce(0.0) { $0 + $1.weight }
            var randomValue = Double.random(in: 0..<totalWeight)
            
            for (index, item) in remainingWords.enumerated() {
                randomValue -= item.weight
                if randomValue <= 0 {
                    selectedWords.append(item.word)
                    remainingWords.remove(at: index)
                    break
                }
            }
        }
        
        log("   Выбрано \(selectedWords.count) слов\n")
        
        return selectedWords
    }
    
    // Получить слова для повторения
    func getWordsForReview(from allWords: [Word]) -> [Word] {
        let now = Date()
        let wordsNeedingReview = allWords.filter { word in
            if let stat = statistics[word.id] {
                return stat.nextReviewDate <= now && !word.isHidden
            }
            return !word.isHidden
        }
        
        return wordsNeedingReview.sorted { word1, word2 in
            let stat1 = statistics[word1.id]
            let stat2 = statistics[word2.id]
            
            if stat1 == nil && stat2 == nil {
                return true
            }
            if stat1 == nil {
                return false
            }
            if stat2 == nil {
                return true
            }
            
            // Сортируем по приоритету: сначала самые просроченные
            let overdue1 = now.timeIntervalSince(stat1!.nextReviewDate)
            let overdue2 = now.timeIntervalSince(stat2!.nextReviewDate)
            
            // С учетом кривой забывания
            let priority1 = overdue1 * (1.0 + stat1!.forgettingCurve)
            let priority2 = overdue2 * (1.0 + stat2!.forgettingCurve)
            
            return priority1 > priority2
        }
    }
    
    // Сброс счетчиков сессии
    func resetSession() {
        sessionStartTime = Date()
        sessionErrorCount = 0
        sessionCorrectCount = 0
    }
    
    // Получить статистику по слову
    func getStatistics(for wordId: UUID) -> WordStatistics? {
        return statistics[wordId]
    }
    
    // Получить общую статистику
    func getOverallStatistics() -> (total: Int, mastered: Int, learning: Int, new: Int, difficult: Int) {
        let total = statistics.count
        var mastered = 0
        var learning = 0
        var difficult = 0
        
        for stat in statistics.values {
            if stat.easeFactor >= 2.3 && stat.correctAnswers >= 10 && stat.difficultyLevel <= 0.2 && stat.consecutiveCorrect >= 5 {
                mastered += 1
            } else if stat.difficultyLevel >= 0.7 || stat.wrongAnswers > stat.correctAnswers * 2 {
                difficult += 1
            } else if stat.repetitionNumber > 0 {
                learning += 1
            }
        }
        
        let new = total - mastered - learning - difficult
        return (total, mastered, learning, new, difficult)
    }
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([UUID: WordStatistics].self, from: data) {
            statistics = decoded
        }
    }
}

enum ErrorContext {
    case expertSlip // эксперт оступился
    case temporaryLapse // временная ошибка
    case fatigue // усталость
    case struggling // проблемы с запоминанием
    case difficultWord // сложное слово
    case earlyLearning // начальное изучение
    case normalError // обычная ошибка
}
