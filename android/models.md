# AI Models in My Tutor

This document details the Large Language Models (LLMs) and inference architecture utilized within the **My Tutor** application.

---

## 1. Overview of Model Architecture

My Tutor operates with a **privacy-first, on-device intelligence architecture**. The application is designed to run localized GGUF quantized neural networks on edge hardware (mobile CPUs/NPUs) without sending user prompts, textbook scans, or audio recordings to external cloud servers.

The application incorporates a multi-tier inference pipeline:
1. **Tier 1 (High Performance On-Device GGUF):** When a supported open-weight model is downloaded, inference runs 100% locally on the device using `llama.cpp` through `llama_cpp_dart`.
2. **Tier 2 (Built-in Heuristic Professor AI Engine):** A zero-download, 100% offline rule-based and template-backed expert system covering B.Tech engineering core subjects with mathematical formula formatting and LaTeX-to-Unicode conversion.
3. **Tier 3 (Optional Cloud AI via Pollinations - User Opt-In):** Explicitly toggled in Settings for general web inquiries when the student is connected to the internet.

---

## 2. Supported On-Device GGUF Models

### Model 1: Google Gemma 4 (2B Parameter) — Primary Model
* **Model Identifier:** `gemma-4-2b-it-Q4_K_M.gguf` (`google_gemma-4-E2B-it-Q4_K_M.gguf`)
* **Display Name:** Gemma 4 (2B Parameter)
* **Author / Provider:** Google DeepMind / Google
* **Source:** Hugging Face (`bartowski/google_gemma-4-E2B-it-GGUF`)
* **License:** Apache License 2.0
* **Format & Quantization:** GGUF, 4-bit medium quantization (`Q4_K_M`)
* **Context Window:** 4,096 tokens
* **Disk Size:** ~1.3 GB (downloadable package)
* **Runtime RAM Footprint:** ~1.4 GB RAM
* **Specialization in My Tutor:**
  * Primary on-device engineering tutor model.
  * Specialized in conceptual engineering pedagogy, mathematical derivations, physics principles, and structured step-by-step reasoning.
  * Formatted with custom female professor prompt persona ("Prof. AI").

### Model 2: Alibaba Cloud Qwen 2.5 (1.5B Parameter)
* **Model Identifier:** `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf`
* **Display Name:** Qwen 2.5 (1.5B Parameter)
* **Author / Provider:** Alibaba Cloud (Qwen Team)
* **Source:** Hugging Face (`Qwen/Qwen2.5-1.5B-Instruct-GGUF`)
* **License:** Apache License 2.0
* **Format & Quantization:** GGUF, 4-bit medium quantization (`Q4_K_M`)
* **Context Window:** 4,096 tokens
* **Disk Size:** ~1.1 GB
* **Runtime RAM Footprint:** ~1.1 GB RAM
* **Specialization in My Tutor:**
  * Exceptional capabilities in programming, C memory management, pointers, and Data Structures & Algorithms (DSA).
  * Fast generation of verified code implementations, algorithm complexity proofs, and logic tracing.

### Model 3: Meta Llama 3.2 (1B Parameter)
* **Model Identifier:** `Llama-3.2-1B-Instruct-Q4_K_M.gguf`
* **Display Name:** Llama 3.2 (1B Parameter)
* **Author / Provider:** Meta Platforms, Inc.
* **Source:** Hugging Face (`bartowski/Llama-3.2-1B-Instruct-GGUF`)
* **License:** Llama 3.2 Community License Agreement
* **Format & Quantization:** GGUF, 4-bit medium quantization (`Q4_K_M`)
* **Context Window:** 4,096 tokens
* **Disk Size:** ~0.7 GB
* **Runtime RAM Footprint:** ~750 MB RAM
* **Specialization in My Tutor:**
  * Ultra-compact edge model optimized for low-end or budget Android devices with limited physical memory.
  * Rapid inference speed for quick definitions, unit conversions, and concise revision queries.

---

## 3. Built-in Offline Fallback Engine (Prof. AI)

* **Engine Name:** `Prof. AI (Offline Engine)`
* **Architecture:** Rule-based heuristics, syllabus-indexed knowledge graphs, and dynamic regex mathematical parsing.
* **Storage Footprint:** 0 MB extra download (compiled natively into the application).
* **Network Requirement:** None (100% offline).
* **Coverage:**
  * **Engineering Physics:** Semiconductors & Band Theory, Lasers & Optical Fiber, Quantum Mechanics, Wave Optics (Interference, Diffraction, Polarization).
  * **Engineering Chemistry:** Polymers, Lithium-ion batteries, Fuel cells, Corrosion control, Nanomaterials.
  * **Engineering Mathematics:** Eigenvalues & Cayley-Hamilton Theorem, Partial Differentiation (Implicit multivariable functions), Matrix diagonalization.
  * **Data Structures & Algorithms:** Arrays, Linked Lists, Trees, Graphs, Sorting & Searching, Asymptotic complexity.
  * **C Programming:** Pointers, Dynamic Memory Allocation (`malloc`, `calloc`, `free`), Structs, Bitwise operations.

---

## 4. Inference Engine & Execution Pipeline

1. **llama.cpp / llama_cpp_dart Runtime:**
   * Models are executed natively using precompiled ARM64 / x86_64 native shared libraries (`libllama.so`, `libggml.so`, `libggml-cpu.so`, `libggml-base.so`, `libmtmd.so`).
   * Inference is dispatched in a dedicated background worker isolate to ensure the Flutter 120Hz/90Hz UI thread remains completely fluid.
   * Execution configuration: 4 CPU compute threads (`nThreads: 4`), batch size 512 (`nBatch: 512`), memory-mapped model files (`useMmap: true`) to prevent Out-Of-Memory (OOM) operating system kills.

2. **Mathematical Notation Post-Processing (`formatMathTypography`):**
   * Automatically strips raw LaTeX backslash commands and transforms complex equations into clean Unicode symbols:
     * Fractions: `\frac{a}{b}` -> `a/b`
     * Greek alphabet: `\alpha` -> `α`, `\theta` -> `θ`, `\lambda` -> `λ`, etc.
     * Roots: `\sqrt{x}` -> `√(x)`, `\sqrt[3]{x}` -> `∛(x)`
     * Calculus & Operators: `\partial` -> `∂`, `\int` -> `∫`, `\sum` -> `∑`, `\infty` -> `∞`, `\pm` -> `±`
     * Subscripts and superscripts: `x^2` -> `x²`, `u_{x}` -> `uₓ`, `a_1` -> `a₁`
   * Ensures output is readable in plain text and articulates naturally when spoken aloud via Text-to-Speech (TTS).

3. **Context Window & Chat History Management:**
   * Context memory buffers up to 20 recent conversation turns per chapter room.
   * Automatic stripping of reasoning/scratchpad tags (`<think>...</think>`) before feeding historical turns back into prompt generation.
   * Strict chapter isolation: documents and attachments uploaded in one chapter are never leaked into other rooms.
