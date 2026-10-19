class PrivacyPolicyText {
  static const String lastUpdated = '18-10-2026';
  static const String appName = 'My Tutor';
  static const String developerName = 'Usman Raza';
  static const String contactEmail = 'usman.raza.txt@gmail.com';
  static const String jurisdiction = 'Uttar Pradesh, India';

  static const String content = '''
# Privacy Policy

**Last Updated:** $lastUpdated  
**Application:** $appName ("the App")  
**Developer/Entity:** $developerName  
**Contact:** $contactEmail  

---

### 1. Privacy Philosophy & On-Device Architecture
$appName is engineered from the ground up with a **local-first, privacy-by-design architecture**. We believe that your academic notes, study questions, exam preparation materials, and conversational doubts belong solely to you.

- **On-Device Artificial Intelligence:** When using downloaded open-weight models (Google Gemma 4, Qwen 2.5, Meta Llama 3.2) or the built-in tutor engine, **all language model inference executes entirely on your device's local CPU and memory**.
- **No Developer Servers:** We do not operate proprietary backend servers that collect, log, store, or profile your questions, chat history, or uploaded study files.

---

### 2. Information Stored Locally on Your Device
All data generated within $appName is stored locally in your device's private application storage:
1. **Chat Messages & History:** Text questions, answers, and timestamps categorized by subject and chapter room.
2. **Uploaded Documents & Notes:** Local file paths, document names, and text extracted from PDFs or images.
3. **User Preferences:** Voice speed, response language (English, Hindi, Hinglish), active AI model selection, and terms acceptance state.

#### How You Can Delete Your Data
You maintain complete control over your data and can delete it at any time:
- **Delete an Individual Chat:** Open any chat room, tap the three-dot menu (⋮) in the top-right corner, and select **Clear Room Chat**. A confirmation dialog ensures this action is intentional.
- **Delete a Chapter or Subject:** Long-press or tap the delete action on any chapter or subject in the Subject Detail screen.
- **Clear All Data:** Navigate to **Settings > Storage & Data Management > Clear All Data**. This permanently deletes all stored chat messages, saved documents, and cached preferences from your device.

---

### 3. Device Permissions (All Strictly Optional)
$appName requests the following device permissions only when you activate specific features. You can use the app without granting these permissions by typing manually:
- **Camera (`android.permission.CAMERA`):** Required only when you use the "Scan Question Photo" tool to photograph a textbook problem, circuit diagram, or handwritten formula. Captured photos are processed locally on-device.
- **Photos / Files (`READ_MEDIA_IMAGES` / File Access):** Required only when you choose to attach existing PDF lecture notes, TXT files, or gallery photos for document analysis.
- **Microphone (`android.permission.RECORD_AUDIO`):** Required only when you tap the microphone button to dictate questions using voice input.

---

### 4. Network Connections & Third-Party Services
By default, $appName operates 100% offline once models are installed. The App makes network connections **only** under the following specific circumstances:

1. **AI Model Downloads (Hugging Face):**
   - Downloaded GGUF neural network weights (Gemma 4, Qwen 2.5, Llama 3.2) are retrieved from Hugging Face (`https://huggingface.co/`).
   - Downloads occur **only when you explicitly tap "Download"** in Settings. Downloads are governed by Hugging Face's privacy policy.
2. **Online AI Mode (Pollinations AI - Explicit Opt-In):**
   - In Settings, there is an optional toggle labeled **"Online AI & Internet Search (Opt-In)"**.
   - By default, this toggle is **disabled**.
   - **Notice:** If you explicitly enable this toggle, your question text, current subject/chapter topic, and relevant document context are transmitted over HTTPS to Pollinations AI (`https://text.pollinations.ai/`) to generate real-time online responses. If you do not wish for your questions to leave your device, keep this toggle turned off.
3. **Response Translation (Google Translate):**
   - If you tap the "Translate" button on an AI message bubble to view the answer in Hindi, English, or Hinglish, the text of that specific message is transmitted to Google's translation endpoint (`https://translate.googleapis.com`) to retrieve the translation.
4. **Online Code Compilation (Wandbox API):**
   - If you use the Code Runner screen to execute programming code online, the source code is sent to Wandbox (`https://wandbox.org/api/compile.json`) for execution.

---

### 5. Third-Party Libraries & Subsystems
- **Google ML Kit Text Recognition:** Extracts text from camera photos and gallery images using Google ML Kit's Latin script OCR model. Text extraction executes **100% locally on your device** without transmitting images to Google cloud servers.
- **Speech-to-Text Voice Recognition:** Interfaces with your device's operating system speech recognition provider (such as Google Speech Services on Android or Apple Dictation on iOS). Depending on your operating system settings and whether offline speech recognition files are installed on your device, the OS recognizer may process speech on-device or transmit audio snippets to the OS provider's servers in accordance with their respective privacy policies.
- **Text-to-Speech Audio Synthesis:** Interfaces with your device's built-in text-to-speech engine (Google TTS, Samsung TTS, or Apple AVFoundation). Audio synthesis is performed locally on your device.
- **3D Interactive Solver:** Renders the 3D Rubik's Cube solver locally on-device. It does not connect to external servers or load external trackers.
- **Open-Weight AI Models:**
  - Google Gemma 4 (2B) — Apache 2.0 License
  - Qwen 2.5 (1.5B) — Apache 2.0 License
  - Meta Llama 3.2 (1B) — Llama 3.2 Community License

---

### 6. No Tracking, Analytics, or Advertising
- **No Analytics:** We do not track user behavior, page views, or app sessions.
- **No Advertising:** $appName contains zero third-party advertising SDKs and displays no ads.
- **No Accounts or Logins:** You are not required to create an account, register an email, or provide personal identity data to use $appName.

---

### 7. Children's Privacy
$appName is intended for university and higher education students. We do not knowingly collect personal identifiable information from children.

---

### 8. Policy Acceptance & Version Changes
On first launch, $appName presents a Terms & Privacy Acceptance screen. Acceptance is recorded locally in your device settings. If this Privacy Policy is updated materially in a future release, you will be presented with the updated terms upon first launch of that version.

---

### 9. Contact Us
If you have questions or inquiries regarding your privacy or this policy, please contact:  
**Email:** $contactEmail  
**Jurisdiction:** $jurisdiction  
''';
}
