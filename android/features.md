# Features & Capabilities of My Tutor

**My Tutor** is an offline-first AI personal professor and voice-interactive study companion engineered specifically for B.Tech and engineering undergraduates.

---

## 1. Languages Supported

My Tutor features a trilingual educational engine with instant multi-language switching:

1. **Hinglish (Default & Recommended):**
   * **Style:** The natural, conversational dialect of Indian engineering students — combines everyday Hindi grammatical structures with formal English engineering terminology (e.g., *"Is equation ko dono taraf differentiate karo aur terms group karo"*).
   * **Advantage:** Eliminates awkward overly formal translations while preserving standard textbook technical terms (*eigenvalues*, *stimulated emission*, *pointers*, *band gap*).

2. **English:**
   * **Style:** Formal technical English adhering to engineering university examination and textbook standards.
   * **Advantage:** Ideal for preparing answers for semester exams, assignments, and academic papers.

3. **Pure Devanagari Hindi (हिन्दी):**
   * **Style:** Complete Devanagari Hindi technical explanations with proper feminine professor honorific forms (*"मैं समझाती हूँ"*).
   * **Advantage:** Accessible to students from Hindi-medium academic backgrounds.

4. **On-Demand Bubble Translation:**
   * Every AI response bubble includes a **Translate (अनुवाद)** button allowing instantaneous translation between English, Hindi, and Hinglish.

---

## 2. Core Educational Features

### 100% Offline Intelligence
* All core capabilities—text answering, PDF analysis, photo note OCR, voice synthesis, and chat history—work completely without an internet connection once GGUF models are installed (or using the built-in offline engine).
* No cloud dependence, zero tracking, and absolute privacy for student study materials.

### Subject & Chapter Room Organization
* Pre-configured, structured engineering curriculum:
  * **Engineering Physics:** Semiconductors & Band Theory, Lasers & Optical Fiber, Wave Optics, Quantum Mechanics.
  * **Engineering Chemistry:** Polymers & Composites, Batteries & Energy Storage, Corrosion Control.
  * **Engineering Mathematics:** Eigenvalues & Diagonalization, Partial Differentiation, Cayley-Hamilton Theorem.
  * **Data Structures & Algorithms (DSA):** Arrays, Linked Lists, Trees, Graphs, Sorting & Complexity.
  * **C & Memory Management:** Pointers, Dynamic Memory Allocation, Structs, Bitwise operations.
  * **General Doubts Room:** Cross-disciplinary engineering inquiries.
* Dedicated chat room per chapter with independent message history and document memory.

### Multi-Modal Doubt Input
* **Interactive Text Input:** Fluid text field with smart suggested starter prompts for rapid questioning.
* **Voice-to-Text (STT):** Dictate doubts hands-free in Hinglish or English with real-time waveform sound level animations.
* **Photo OCR Scanner (Camera / Gallery):**
  * Snap a picture of handwritten notes, textbook numerical problems, or circuit diagrams.
  * On-device Google ML Kit OCR extracts text in milliseconds.
  * Option to add a specific question caption (e.g. *"Is formula ko derive karo"*) or request general explanation.
* **PDF & Document Attachments:**
  * Upload lecture slides, PDF notes, or text documents.
  * Extracted text is indexed into room memory for contextual Q&A and viva preparation.

### Audio Voice Tutoring (Sunao TTS)
* **Voice Professor Persona ("Prof. AI"):** Encouraging, clear female professor voice providing step-by-step guidance.
* **Auto-Speak Toggle:** Automatically vocalizes answers as they finish generating.
* **Custom Audio Speed:** Adjustable speech rate (0.25x to 1.0x) in Settings.
* **Individual Message Read-Aloud:** Tap the "Sunao (TTS)" button on any message bubble to listen or pause at any time.

### Mathematical & Code Typography
* **Clean Math Formatter:** Converts raw LaTeX backslashes into elegant, human-readable Unicode symbols:
  * Superscripts ($x²$, $x⁻¹$), subscripts ($a₁$, $uₓ$), fractions ($a/b$), roots ($√(x)$), integrals ($∫$), and sums ($∑$).
  * Perfectly readable on small screens and cleanly pronounced by text-to-speech engines.
* **Code Blocks:** Syntax-highlighted code display with quick copy-to-clipboard actions.

### 3D Interactive Rubik's Cube Solver
* Algorithmic logic and spatial reasoning tutor with a fully interactive 3D WebGL cube.
* Supports face-by-face manual color input, randomized scramble, and step-by-step animated solutions using the Kociemba Two-Phase algorithm.

### Multi-Language Code Runner
* In-app programming workbench supporting C, C++, Python, and Java.
* Write, edit, and compile code directly to verify tutorial concepts.

---

## 3. Storage, Privacy & Data Management

* **Per-Room Partitioned Storage:** Every chapter room stores its conversations in independent, compact JSON files (`tutor_data/chats/{chapterId}.json`), ensuring near-instant load times even with large histories.
* **Storage Breakdown Dashboard:** View disk usage broken down by chat messages, documents, AI models, and backups in Settings.
* **Data Control:**
  * One-tap **Clear Room Chat** with safety confirmation dialog.
  * **Clear All Data** in Settings for a full reset.
* **Legal Transparency:** Built-in Terms of Use, Privacy Policy, and Open Source License inspection.

  ## Upcoming Features
  * **Mock Test:** User's activity/units as per subject mock test questions ( user can set  no. of questions as per their choice ).
  * **Syllabus Tracking/Progress :** User can upload their syllabus and track their progress.
  * **Smart Study Planner :** My tutor can track their progress of their syllabus and it can suggest what he/she needs to cover.
  * **Multilingual Learning :** Upcoming updates will have multilanguage learning experience to the users. 
