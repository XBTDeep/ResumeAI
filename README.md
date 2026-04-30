# ResumeAI

ResumeAI is a one-screen SwiftUI app that compares a resume against a job posting and returns a professional scorecard with strengths, gaps, suggestions, matched keywords, and resume bullet rewrites.

## Stack

- SwiftUI
- MVVM
- Clean Architecture
- PDFKit for PDF resume text extraction
- Vision OCR for resume images
- URLSession + HTML cleanup for public job links
- Local scoring plus an isolated `LocalQwenLLMService` boundary for Qwen/GGUF inference

## Current Input Support

Resume:
- Paste text
- Upload PDF
- Upload TXT/RTF
- Upload image from Photos, then OCR locally

Job:
- Public job URL
- Pasted job description fallback

## Architecture

```text
Presentation
- SwiftUI views
- ResumeMatchViewModel
- reusable scorecard/input components

Domain
- entities
- repository protocols
- use cases
- deterministic scoring service

Data / Infrastructure
- resume extraction repository
- job description repository
- local Qwen suggestion service boundary
```

## Local Qwen Plan

The app is ready for `Qwen2.5-0.5B-Instruct-GGUF` behind `LocalQwenLLMService`. The current implementation keeps everything local and returns deterministic advice until a llama.cpp/Core ML runner and bundled GGUF model are added.

Recommended model: `Qwen2.5-0.5B-Instruct-GGUF`, 4-bit quantized.

## Build

```sh
xcodebuild -project ResumeAI.xcodeproj -scheme ResumeAI -destination 'generic/platform=iOS Simulator' build
```
