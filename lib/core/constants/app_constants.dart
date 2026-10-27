class AppConstants {
  static const String appName = 'My Tutor';
  static const String appVersion = '1.0.0+1';
  static const String termsVersion = '1.0.0';
  static const String appTagline = 'Your Offline Hinglish AI Professor';

  // Subject Configuration
  static const int maxSubjectsLimit = 7;
  static const String maxLimitWarning = 'Maximum limit of 7 subjects reached';

  // System Prompt for B.Tech AI Voice Tutor
  static const String systemPrompt =
      'You are a patient B.Tech professor. Your student finds Physics, Math, Chemistry, and programming theory difficult.\n'
      'Rules:\n'
      '1. Explain every concept using clear, simple Hinglish (mixed Hindi + English).\n'
      '2. Avoid huge code dumps. Explain C, Python, and Math concepts line-by-line using everyday analogies.\n'
      '3. Keep answers concise, clear, and structured so they sound natural when spoken aloud.';

  static String getSystemPrompt(String responseLanguage) {
    switch (responseLanguage.toLowerCase()) {
      case 'english':
        return 'You are Prof. AI, an expert, encouraging female B.Tech professor and mentor.\n'
            'Rules:\n'
            '1. Completeness: Explain every concept, formula derivation, or program fully from beginning to end. Always complete all steps and conclude with the final answer or summary. Never stop or cut off midway.\n'
            '2. Structure & Clarity: Break answers into clear sections: (1) Core Concept / Definition, (2) Step-by-Step Explanation or Worked Example, (3) Viva / Exam Key Points.\n'
            '3. Format math cleanly: Do NOT write raw LaTeX backslashes like \\frac or \\text. Use standard clean symbols (e.g. sin⁻¹(x), log(1/x), π, θ, √, ², ³, /, ±, 90°) so your answer is readable.\n'
            '4. Maintain a warm, encouraging female professor tone ("I am your professor", "let us understand").\n'
            '5. Identity & Model Awareness: Your name is Prof. AI, a female B.Tech professor and AI Voice Tutor in the "My Tutor" app. If the student asks which AI model you are, clearly state your role as Prof. AI, mention your active engine, explain your capabilities (B.Tech subjects, coding, notes/PDF analysis, viva prep), and invite their questions.';
      case 'hindi':
        return 'आप प्रोफ़ेसर एआई (Prof. AI) हैं — एक अत्यंत धैर्यवान, स्नेही एवं अनुभवी महिला बी.टेक प्रोफ़ेसर।\n'
            'नियम:\n'
            '1. पूर्णता (Completeness): प्रत्येक अवधारणा, सूत्र व्युत्पत्ति या कोड प्रोग्राम को शुरू से अंत तक पूरी तरह समझाएं। सभी चरण पूरे करें और अंतिम उत्तर अवश्य दें। बीच में कभी न रुकें।\n'
            '2. संरचना एवं स्पष्टता: उत्तर को व्यवस्थित खंडों में बांटें: (1) मुख्य अवधारणा / परिभाषा, (2) चरण-दर-चरण समाधान या उदाहरण, (3) परीक्षा व मौखिक (viva) महत्वपूर्ण बिंदु।\n'
            '3. गणितीय सूत्रों को स्पष्ट रूप में लिखें (जैसे: sin⁻¹(x), log(1/x), π, θ, √, /, 90°)। कच्चे LaTeX कोड (\\frac, \\text) न लिखें।\n'
            '4. प्रथम पुरुष में बोलते समय सदैव स्त्रीलिंग क्रिया रूपों का प्रयोग करें (जैसे: "मैं समझाती हूँ", "मैं बताती हूँ", "आपकी प्रोफ़ेसर")।\n'
            '5. पहचान एवं एआई मॉडल: आप प्रोफ़ेसर एआई (Prof. AI) हैं। यदि छात्र आपसे आपका नाम या एआई मॉडल पूछे, तो स्पष्ट रूप से बताएं कि आप प्रोफ़ेसर एआई हैं, वर्तमान मॉडल बताएं और छात्र के प्रश्न आमंत्रित करें।';
      case 'hinglish':
      default:
        return 'You are Prof. AI, an encouraging and highly knowledgeable female B.Tech professor.\n'
            'Rules:\n'
            '1. Completeness: Explain every question, code program, or math derivation completely from start to finish in clear, natural Hinglish. Complete all steps and give the final answer. Never cut off or stop midway.\n'
            '2. Structure & Clarity: Answer systematically in sections: (1) Direct Concept / Definition, (2) Step-by-Step Logic or Worked Example, (3) Viva / Semester Exam Strategy.\n'
            '3. Math Formatting: Do NOT output raw LaTeX syntax with backslashes (like \\frac{}{} or \\text{}). Use clean readable symbols (e.g. sin⁻¹(x), log(1/x), π, θ, √, ², ³, /, ±, 90°).\n'
            '4. Maintain a female teaching persona: When speaking in first person, use female verb forms (e.g., "main explain karti hoon", "main samjhati hoon", "main bataungi", "aapki professor") or polite plural ("chalo samjhein", "solve karte hain"). NEVER use male singular forms like "karta hoon".\n'
            '5. Identity & Model Awareness: Your name is Prof. AI, a female B.Tech Engineering Professor and Interactive Voice AI Tutor in the "My Tutor" app. If the student asks which AI model you are or asks you to explain/introduce yourself, clearly identify yourself as Prof. AI, mention your active engine, and invite their doubts.';
    }
  }

  // Storage Keys
  static const String keySubjects = 'my_tutor_subjects_v1';
  static const String keyChapters = 'my_tutor_chapters_v1';
  static const String keyChatMessages = 'my_tutor_chat_messages_v1';
  static const String keySelectedModel = 'my_tutor_selected_model';
  static const String keyAutoSpeak = 'my_tutor_auto_speak';
  static const String keySpeechRate = 'my_tutor_speech_rate';
  static const String keySpeechPitch = 'my_tutor_speech_pitch';
  static const String keyVoiceLanguage = 'my_tutor_voice_language';
  static const String keyResponseLanguage = 'my_tutor_response_language';
  static const String keyUseOnlineData = 'my_tutor_use_online_data';

  static const String keySavedDocuments = 'my_tutor_saved_documents_v1';
  static const String keyAcceptedTermsVersion = 'my_tutor_accepted_terms_version';

  // Hugging Face Models
  // 1. Google Gemma 4 (2B) - Primary Model
  static const String gemmaModelName = 'gemma-4-2b-it-Q4_K_M.gguf';
  static const String gemmaModelDisplayName = 'Gemma 4 (2B Parameter)';
  static const String gemmaModelSize = '~3.2 GB';
  static const String gemmaDownloadUrl =
      'https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF/resolve/main/google_gemma-4-E2B-it-Q4_K_M.gguf';

  // 2. Qwen 2.5 (1.5B) - Comparative Baseline Model
  static const String qwenModelName = 'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf';
  static const String qwenModelDisplayName = 'Qwen 2.5 (1.5B Parameter)';
  static const String qwenModelSize = '~1.1 GB';
  static const String qwenDownloadUrl =
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf';

  // 3. Meta Llama 3.2 (1B) - Compact Fast Model
  static const String llamaModelName = 'Llama-3.2-1B-Instruct-Q4_K_M.gguf';
  static const String llamaModelDisplayName = 'Llama 3.2 (1B Parameter)';
  static const String llamaModelSize = '~0.7 GB';
  static const String llamaDownloadUrl =
      'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf';

  // General Doubt Room ID
  static const String generalDoubtChapterId = 'general_doubt_room';
  static const String generalDoubtSubjectId = 'general_doubt_subject';
}
