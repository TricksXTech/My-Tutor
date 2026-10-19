# Open-Source Tools & Libraries in My Tutor

This document catalogs the open-source frameworks, software development kits (SDKs), libraries, and tools powering **My Tutor**.

---

## 1. Core Framework & State Architecture

### Flutter & Dart SDK
* **Role:** Cross-platform reactive UI framework and runtime.
* **License:** BSD 3-Clause License
* **Usage:** Provides declarative UI rendering, native 120Hz scrolling pipelines, platform channels, and multi-threaded Dart isolates.

### Provider (`package:provider`)
* **Role:** State management and dependency injection.
* **License:** MIT License
* **Usage:** Manages application-wide state across `ChatProvider`, `ChapterProvider`, `SubjectProvider`, and `TutorSettingsProvider`, ensuring reactive rebuilds with high granular efficiency.

---

## 2. On-Device AI & Machine Learning Tools

### llama_cpp_dart (`llama.cpp`)
* **Role:** High-performance on-device Large Language Model (LLM) inference engine.
* **License:** MIT License
* **Usage:** Bridges Dart code via FFI (Foreign Function Interface) directly into native C/C++ `llama.cpp` shared libraries (`libllama.so`, `libggml.so`). Enables local GGUF 4-bit quantized transformer inference on mobile ARM64/ARMv8 architectures without internet access.

### Google ML Kit Text Recognition (`package:google_mlkit_text_recognition`)
* **Role:** On-device Optical Character Recognition (OCR).
* **License:** Apache License 2.0
* **Usage:** Extracts textual problems, textbook equations, and lab manuals directly from camera photographs and gallery images. Operates 100% locally on-device without network transmission.

### Syncfusion Flutter PDF (`package:syncfusion_flutter_pdf`)
* **Role:** Local PDF parsing and document indexing.
* **License:** Syncfusion Community License / Commercial License
* **Usage:** Extracts full textual content and chapter sections from uploaded student PDF lecture notes for context memory injection.

---

## 3. Voice & Audio Tools

### Flutter TTS (`package:flutter_tts`)
* **Role:** Text-to-Speech (TTS) voice synthesis.
* **License:** BSD 3-Clause License
* **Usage:** Powers the voice teaching persona ("Sunao TTS"). Interfaces with Android's TextToSpeech engine to vocalize engineering explanations in natural Hinglish, English, or Hindi at adjustable speeds.

### Speech to Text (`package:speech_to_text`)
* **Role:** Voice recognition and real-time audio transcription.
* **License:** BSD 3-Clause / MIT License
* **Usage:** Converts student spoken questions into text in real time with an animated audio waveform sound level visualizer.

---

## 4. Local Storage & File System

### Path Provider (`package:path_provider`)
* **Role:** File system path discovery.
* **License:** BSD 3-Clause License
* **Usage:** Resolves persistent private application documents directories (`/data/user/0/com.mytutor.my_tutor/app_flutter/`) for storing per-room chat files, documents, and downloaded model weights.

### SharedPreferences (`package:shared_preferences`)
* **Role:** Fast key-value persistent storage.
* **License:** BSD 3-Clause License
* **Usage:** Persists lightweight user settings including voice speed, response language preferences, auto-speak state, and terms acceptance flags.

### Custom File-Based JSON Storage Engine (`FileStorageService`)
* **Role:** Partitioned, debounced persistent data engine.
* **Architecture:**
  * One JSON file per chat room: `tutor_data/chats/{chapterId}.json`
  * One JSON file per document: `tutor_data/documents/{docId}.json`
  * Debounced file writes with background isolate serialization (`Isolate.run`), preventing any frame drops on the main UI thread.

---

## 5. Networking & HTTP Tools

### Dio (`package:dio`)
* **Role:** Advanced HTTP client for model downloads.
* **License:** MIT License
* **Usage:** Handles multi-gigabyte GGUF model file downloads from Hugging Face with chunked streaming, progress percentage tracking, cancel tokens, and error recovery.

### HTTP (`package:http`)
* **Role:** Lightweight networking.
* **License:** BSD 3-Clause License
* **Usage:** Dispatches optional external requests (Google Translate API, Pollinations AI, and Wandbox code compilation).

---

## 6. UI, Typography & Visualizer Components

### Google Fonts (`package:google_fonts`)
* **Role:** Modern typography rendering.
* **License:** Apache License 2.0 / SIL Open Font License
* **Usage:** Renders `Poppins` for clean headers and `Inter` for highly readable body copy, code, and mathematical explanations.

### Flutter Markdown (`package:flutter_markdown`)
* **Role:** Rich text, tables, and formatted documentation rendering.
* **License:** BSD 3-Clause License
* **Usage:** Formats AI responses containing markdown headings, bulleted lists, bold emphasis, blockquotes, and tables.

### Cuber & 3D Interactive Solver (`package:cuber`, WebGL)
* **Role:** Rubik's cube solver algorithm and 3D visualizer.
* **License:** MIT License
* **Usage:** Executes Kociemba Two-Phase solving algorithms and displays an interactive, hardware-accelerated 3D cube model for spatial algorithm tutoring.

### Image Picker & File Picker (`package:image_picker`, `package:file_picker`)
* **Role:** Native media and file selector dialogs.
* **License:** BSD 3-Clause / MIT License
* **Usage:** Permits students to take camera photos of questions or select PDF notes and documents from device storage.
