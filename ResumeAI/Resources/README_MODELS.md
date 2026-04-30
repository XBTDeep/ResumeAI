# Local Qwen Model

Place a quantized GGUF model in `Resources/Models` when a llama.cpp/Core ML runtime is connected.

Required test model: `Qwen3.5-0.8B-GGUF`, Q4_K_M quantization.
Expected local filename: `Qwen3.5-0.8B.q4_k_m.gguf`.

The app also checks the app sandbox's local `Documents` and `Documents/Models` directories for that exact GGUF filename, which is useful for simulator/dev builds where you do not want to bundle a large model in the app target.

The app uses `llama.swift`, which wraps llama.cpp, to run the local GGUF from `LocalQwenSuggestionService`. There is no deterministic advice fallback: if the 0.8B model is missing, inference fails, or Qwen returns unusable JSON, the app surfaces the error instead of showing fabricated ATS advice.
