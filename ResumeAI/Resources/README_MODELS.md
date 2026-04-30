# Local Qwen Model

Place a quantized GGUF model here when a llama.cpp/Core ML runtime is connected.
Recommended MVP model: `Qwen2.5-0.5B-Instruct-GGUF`, 4-bit quantization.

The app is architected so the `LocalQwenSuggestionService` can be swapped from the current deterministic local fallback to a real GGUF runner without changing Presentation or Domain layers.
