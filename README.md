# ResumeAI

ResumeAI is a one-screen SwiftUI app that compares a resume against a job posting and returns a professional scorecard with strengths, gaps, suggestions, matched keywords, and resume bullet rewrites.

## Architecture

The app uses a feature-based MVVM + Clean Architecture layout.

```text
ResumeAI/
  App/
    ResumeAIApp.swift
    DependencyContainer.swift

  Features/
    ResumeMatch/
      Presentation/
        Views/
        ViewModels/
        Components/
      Domain/
        Models/
        UseCases/
        Protocols/
        Services/
      Data/
        Repositories/
        Services/

  Core/
    DesignSystem/
    Errors/
    Layout/

  Resources/
```

## Layer Rules

- `Presentation` contains SwiftUI views, view models, and UI-only components.
- `Domain` contains business models, use cases, scoring logic, and protocols. It should not depend on SwiftUI, UIKit, PDFKit, Vision, or URLSession.
- `Data` contains concrete implementations for repository protocols and local model services.
- `Core` contains app-wide shared utilities like design tokens, layout helpers, and shared errors.
- `App` contains startup and dependency composition.

## Current Input Support

Resume:
- Paste text
- Upload PDF
- Upload TXT/RTF
- Upload image from Photos, then OCR locally

Job:
- Public job URL
- Pasted job description fallback

## Local Qwen Model

The app runs `Qwen3.5-0.8B-GGUF` behind `LocalQwenSuggestionService` for local ATS-style feedback.

Required model file: `ResumeAI/Resources/Models/Qwen3.5-0.8B.q4_k_m.gguf`.

There is no deterministic advice fallback. If the model is missing or returns invalid JSON, the app shows an error instead of fabricated gaps, suggestions, or rewrites.

## Build

```sh
xcodebuild -project ResumeAI.xcodeproj -scheme ResumeAI -destination 'generic/platform=iOS Simulator' build
```
