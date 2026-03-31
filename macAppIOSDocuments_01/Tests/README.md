# Payslip GPT Test Suite

## Структура

```
Tests/
├── payslip_cases.json   ← все тест-кейсы (добавляй сюда новые PDF)
├── run_tests.py         ← скрипт запуска тестов
└── README.md            ← этот файл
```

## Как запустить

```bash
cd /Users/beliytm/Desktop/macAppDocuments/Tests
python3 run_tests.py
# вводишь API ключ → тестирует все PDF
```

Запустить конкретный тест:
```bash
python3 run_tests.py werckpost-week12
```

Показать список всех тестов:
```bash
python3 run_tests.py --list
```

## Как добавить новый PDF формат

1. Открой `payslip_cases.json`
2. Добавь новый объект в массив:

```json
{
  "id": "worketeers-week12-2026",
  "description": "Worketeers B.V. / Goedhart Bakery — Week 12 (2026), Dutch, irregular hours",
  "source_file": "loonspecificatie-2026-Week-12.pdf",
  "pdf_text": "<текст извлечённый из PDF — скопируй из Xcode консоли>",
  "expected": {
    "netto": 405.13,
    "bruto": 471.01,
    "normalHours": 28.0,
    "irregularHours": 3.0,
    "tax": 47.27,
    "vergoedingen": 0.0,
    "companyName": "Worketeers B.V."
  }
}
```

3. Запусти `python3 run_tests.py` — скрипт сам загружает актуальный промпт из `Tab2Module.swift`

## Как получить текст из PDF

Самый простой способ — после анализа в приложении посмотреть Xcode консоль.
Или: добавь в `extractDatesWithGPT` временный `print(pdfText)` и скопируй вывод.

## Текущие тест-кейсы

| ID | Описание | netto |
|----|----------|-------|
| werckpost-week12-2026 | Sappé, английский, с дорожными | 494.74 |
| werckpost-week11-2026 | Novon, нидерландский, без налога | 149.94 |
| werckpost-week10-2026 | Novon, Mutatie+Totaal колонки | 86.95 |
