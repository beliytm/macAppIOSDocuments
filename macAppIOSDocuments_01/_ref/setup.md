# Setup Instructions

## Requirements
- Xcode 15+
- iOS 17+
- Swift 5.9+

## Installation
1. Open MyIOSAppEnglish.xcodeproj in Xcode
2. Select target device/simulator
3. Build and run (Cmd+R)

## GPT API Key
1. Go to Tab 3 (GPT)
2. Enter your OpenAI API key
3. Key is stored in UserDefaults

## Project Structure (GPT-MODULAR v3.6)
```
MyIOSAppEnglish/
├── AppCore/           # Core - stable, rarely changes
│   ├── BaseModule.swift
│   ├── ModuleRegistry.swift
│   ├── Logger.swift
│   ├── Word.swift
│   └── WordStorage.swift
├── AppModules/        # Modules - independent, replaceable
│   ├── Tab1Module.swift
│   ├── Tab2Module.swift
│   ├── Tab3Module.swift
│   ├── Tab4View.swift
│   └── ...
├── _ref/              # Reference docs (GPT ignores)
└── ContentView.swift  # Main app entry
```

## Module Contract
Every module implements:
- `name`: unique identifier
- `displayName`: UI display name
- `icon`: SF Symbol name
- `dependencies`: required modules
- `initialize()`: setup only
- `execute()`: main work
- `cleanup()`: teardown
- `getView()`: SwiftUI view
