
import 'dart:convert';
import 'package:http/http.dart' as http;

/// High-Performance Translation Service for B.Tech Technical Tutor
/// Seamlessly translates dynamic responses between Hinglish, English, and Hindi
/// while strictly preserving code blocks, math formulas, and technical terminology.
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  /// Asynchronously translates any dynamic text between Hinglish, English, and Hindi.
  /// Preserves code blocks, LaTeX math, and technical terms.
  Future<String> translateTextAsync(String input, String targetLanguage) async {
    if (input.trim().isEmpty) return input;

    final target = targetLanguage.toLowerCase().trim();

    // 1. Separate code blocks and inline code to preserve them verbatim
    final placeholders = <String, String>{};
    int counter = 0;

    // Preserve triple-backtick fenced code blocks (any language, with/without newlines)
    String processed = input.replaceAllMapped(
      RegExp(r'```[\s\S]*?```'),
      (match) {
        final key = 'XZXCB${counter++}XZX';
        placeholders[key] = match.group(0)!;
        return key;
      },
    );

    // Preserve inline code `...`
    processed = processed.replaceAllMapped(
      RegExp(r'`[^`\n]+`'),
      (match) {
        final key = 'XZXIC${counter++}XZX';
        placeholders[key] = match.group(0)!;
        return key;
      },
    );

    // Preserve mathematical expressions and functions so translation doesn't corrupt them
    final mathRegex = RegExp(
      r'sin⁻¹\([^)]+\)|cos⁻¹\([^)]+\)|tan⁻¹\([^)]+\)|log\w*\([^)]+\)|ln\([^)]+\)|'
      r'[0-9]+°|[0-9]+\^\\circ|π\/[0-9]+|sin⁻¹|cos⁻¹|tan⁻¹|\b(sin|cos|tan|log|ln|lim|det)\b',
    );
    processed = processed.replaceAllMapped(mathRegex, (match) {
      final key = 'XZXMT${counter++}XZX';
      placeholders[key] = match.group(0)!;
      return key;
    });

    String translated;

    try {
      if (target == 'hindi') {
        // If already predominantly Hindi
        if (RegExp(r'[\u0900-\u097F]').allMatches(processed).length > 20) {
          translated = processed;
        } else {
          final online = await _fetchGoogleTranslate(processed, 'hi');
          translated = online ?? _convertToHindi(processed);
        }
      } else if (target == 'english') {
        // If already English and has no Devanagari
        final hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(processed);
        if (!hasDevanagari && !_hasHinglishMarkers(processed)) {
          translated = processed;
        } else {
          final online = await _fetchGoogleTranslate(processed, 'en');
          translated = online ?? _convertToEnglish(processed);
        }
      } else {
        // Target: Hinglish
        final hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(processed);
        if (hasDevanagari) {
          translated = _hindiToHinglish(processed);
        } else {
          // Translate English to Hindi, then transliterate to clean Hinglish
          final hindiOnline = await _fetchGoogleTranslate(processed, 'hi');
          if (hindiOnline != null && hindiOnline.isNotEmpty) {
            translated = _hindiToHinglish(hindiOnline);
          } else {
            translated = _convertToHinglish(processed);
          }
        }
      }
    } catch (e) {
      // Fallback to local synchronous dictionary translation on error
      if (target == 'english') {
        translated = _convertToEnglish(processed);
      } else if (target == 'hindi') {
        translated = _convertToHindi(processed);
      } else {
        translated = _convertToHinglish(processed);
      }
    }

    // Restore all placeholders (handling any casing changes or spaces added by translation API)
    placeholders.forEach((placeholder, originalCode) {
      translated = translated.replaceAll(placeholder, originalCode);
      translated = translated.replaceAll(placeholder.toLowerCase(), originalCode);
      translated = translated.replaceAll(placeholder.toUpperCase(), originalCode);

      // Handle translation APIs inserting spaces: e.g. "XZX CB0 XZX" or "xzx mt 1 xzx"
      final cleanKey = placeholder.replaceAll('XZX', '');
      translated = translated.replaceAll(
        RegExp('XZX\\s*$cleanKey\\s*XZX', caseSensitive: false),
        originalCode,
      );
      translated = translated.replaceAll(
        RegExp('___\\s*$cleanKey\\s*___', caseSensitive: false),
        originalCode,
      );
    });

    return translated;
  }

  /// Checks if text contains common conversational Hinglish marker words
  bool _hasHinglishMarkers(String text) {
    final markers = [
      ' hai ', ' hain ', ' yeh ', ' woh ', ' hum ', ' aap ', ' tum ',
      ' samjhein ', ' samjho ', ' karte ', ' karta ', ' karti ',
      ' hota ', ' hoti ', ' hote ', ' nahi ', ' aur ', ' ya ',
      ' kaise ', ' kya ', ' kyun ', ' chalte ', ' chalo ',
      ' mein ', ' par ', ' se ', ' ko ', ' ka ', ' ki ', ' ke '
    ];
    final lower = ' ${text.toLowerCase()} ';
    int count = 0;
    for (final m in markers) {
      if (lower.contains(m)) count++;
    }
    return count >= 2;
  }

  /// Calls Google Translate public API with chunking support
  Future<String?> _fetchGoogleTranslate(String text, String targetLang) async {
    try {
      final lines = text.split('\n');
      final translatedLines = <String>[];

      final buffer = StringBuffer();
      for (final line in lines) {
        if (line.trim().isEmpty) {
          if (buffer.isNotEmpty) {
            final t = await _translateChunk(buffer.toString(), targetLang);
            translatedLines.add(t ?? buffer.toString());
            buffer.clear();
          }
          translatedLines.add('');
          continue;
        }

        if (buffer.length + line.length > 800) {
          final t = await _translateChunk(buffer.toString(), targetLang);
          translatedLines.add(t ?? buffer.toString());
          buffer.clear();
        }

        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(line);
      }

      if (buffer.isNotEmpty) {
        final t = await _translateChunk(buffer.toString(), targetLang);
        translatedLines.add(t ?? buffer.toString());
      }

      return translatedLines.join('\n');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _translateChunk(String text, String targetLang) async {
    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty && data[0] is List) {
          final segments = data[0] as List<dynamic>;
          return segments.map((s) => s[0]?.toString() ?? '').join('');
        }
      }
    } catch (_) {}
    return null;
  }

  /// Converts Devanagari Hindi into natural, crystal-clear B.Tech Hinglish
  String _hindiToHinglish(String hindiText) {
    String dev = hindiText;

    // 1. Direct Devanagari technical and educational replacements BEFORE transliteration
    // This completely prevents Sanskritized Hindi words from transliterating into awkward words like 'falana' or 'vyutkram jya'.
    final devanagariReplacements = {
      'व्युत्क्रम ज्या फलन': 'inverse sine function',
      'व्युत्क्रम ज्या': 'inverse sine',
      'लघुगणक': 'logarithm',
      'अवकलन': 'differentiation',
      'अवकलज': 'derivative',
      'श्रृंखला नियम': 'chain rule',
      'शृंखला नियम': 'chain rule',
      'घात नियम': 'power rule',
      'गुणनफल नियम': 'product rule',
      'भागफल नियम': 'quotient rule',
      'समीकरण': 'equation',
      'आधार': 'base',
      'व्यंजक': 'expression',
      'अभिव्यक्ति': 'expression',
      'फलन': 'function',
      'चर': 'variable',
      'अचर': 'constant',
      'शून्य': 'zero',
      'कोण': 'angle',
      'मान': 'value',
      'रेडियन': 'radians',
      'डिग्री': 'degrees',
      'सरल': 'simplify',
      'उदाहरण': 'example',
      'चरण': 'step',
      'प्रोग्राम': 'program',
      'लूप': 'loop',
      'आउटपुट': 'output',
      'इनपुट': 'input',
      'मांग रही है': 'calculate karna hai',
      'मांग रहा है': 'calculate karna hai',
      'पूछ रहा है': 'poochh raha hai',
      'पूछ रही है': 'poochh rahi hai',
      'आइए': 'chalo',
      'समझें': 'samjhein',
      'तोड़ें': 'todein',
      'दर्शाया जाता है': 'represent kiya jata hai',
      'प्राप्त होता है': 'milta hai',
      'कहा जाता है': 'kaha jata hai',
      'यदि': 'agar',
      'तो': 'toh',
      'क्योंकि': 'kyunki',
      'इसलिए': 'isliye',
      'इसका मतलब है': 'iska matlab hai',
      'बराबर है': 'barabar hai',
      'के बराबर': 'ke barabar',
      'के लिए': 'ke liye',
      'के रूप में': 'ke roop mein',
      'किसी भी': 'kisi bhi',
      'प्रत्येक': 'har',
      'नियम लागू करें': 'rules apply karein',
      'नियमों को लागू करें': 'rules apply karein',
      'समान पदों को मिलाएं': 'like terms combine karein',
    };

    devanagariReplacements.forEach((key, val) {
      dev = dev.replaceAll(key, val);
    });

    // 2. Transliterate remaining conversational Devanagari words to Hinglish
    String text = devanagariToHinglish(dev);

    // 3. Post-transliteration polishing
    text = text.replaceAll(RegExp(r'\bhai\b'), 'hai')
        .replaceAll(RegExp(r'\bhain\b'), 'hain')
        .replaceAll(RegExp(r'\bka\b'), 'ka')
        .replaceAll(RegExp(r'\bki\b'), 'ki')
        .replaceAll(RegExp(r'\bke\b'), 'ke')
        .replaceAll(RegExp(r'\bko\b'), 'ko')
        .replaceAll(RegExp(r'\bse\b'), 'se')
        .replaceAll(RegExp(r'\bpar\b'), 'par')
        .replaceAll(RegExp(r'\bpara\b'), 'par')
        .replaceAll(RegExp(r'\bmein\b'), 'mein')
        .replaceAll(RegExp(r'\bmen\b'), 'mein')
        .replaceAll(RegExp(r'\bkarega\b'), 'karega')
        .replaceAll(RegExp(r'\bkaregee\b'), 'karegi')
        .replaceAll(RegExp(r'\bhota\b'), 'hota')
        .replaceAll(RegExp(r'\bhoti\b'), 'hoti')
        .replaceAll(RegExp(r'\bhote\b'), 'hote')
        .replaceAll(RegExp(r'\bbanata\b'), 'banta')
        .replaceAll(RegExp(r'\bbanati\b'), 'banti')
        .replaceAll(RegExp(r'\byah\b'), 'yeh')
        .replaceAll(RegExp(r'\bvah\b'), 'woh')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  /// Converts Devanagari script phonetically into Latin script
  static String devanagariToHinglish(String text) {
    final buffer = StringBuffer();
    const vowels = {
      'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'i', 'उ': 'u', 'ऊ': 'oo',
      'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'अं': 'an', 'अः': 'ah',
    };
    const matras = {
      'ा': 'a', 'ि': 'i', 'ी': 'i', 'ु': 'u', 'ू': 'oo', 'ृ': 'ri',
      'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ं': 'n', 'ँ': 'n', 'ः': 'h',
    };
    const consonants = {
      'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
      'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
      'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
      'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
      'प': 'p', 'फ': 'f', 'ब': 'b', 'भ': 'bh', 'म': 'm',
      'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v',
      'श': 'sh', 'ष': 'sh', 'स': 's', 'ह': 'h',
      'क्ष': 'ksh', 'त्र': 'tr', 'ज्ञ': 'gya',
    };

    final runes = text.runes.toList();
    for (int i = 0; i < runes.length; i++) {
      final char = String.fromCharCode(runes[i]);
      if (char == '।') {
        buffer.write('.');
      } else if (char == '़') {
        // ignore nuqta
      } else if (vowels.containsKey(char)) {
        buffer.write(vowels[char]);
      } else if (consonants.containsKey(char)) {
        final cons = consonants[char]!;
        if (i + 1 < runes.length) {
          final nextChar = String.fromCharCode(runes[i + 1]);
          if (nextChar == '्') {
            buffer.write(cons);
            i++;
          } else if (matras.containsKey(nextChar)) {
            buffer.write(cons);
            buffer.write(matras[nextChar]);
            i++;
          } else {
            buffer.write('${cons}a');
          }
        } else {
          buffer.write(cons);
        }
      } else if (matras.containsKey(char)) {
        buffer.write(matras[char]);
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// Synchronous fallback: Hinglish -> English -> Hindi -> Original/Hinglish
  String translateText(String input, String targetLanguage) {
    if (input.trim().isEmpty) return input;

    // 1. Separate code blocks and inline code to preserve them verbatim
    final codeBlockPlaceholders = <String, String>{};
    int placeholderCounter = 0;

    // Preserve triple-backtick fenced code blocks
    String processed = input.replaceAllMapped(
      RegExp(r'```[\s\S]*?```'),
      (match) {
        final key = '⟦CB${placeholderCounter++}⟧';
        codeBlockPlaceholders[key] = match.group(0)!;
        return key;
      },
    );

    // Preserve inline code `...`
    processed = processed.replaceAllMapped(
      RegExp(r'`[^`\n]+`'),
      (match) {
        final key = '⟦IC${placeholderCounter++}⟧';
        codeBlockPlaceholders[key] = match.group(0)!;
        return key;
      },
    );

    // 2. Perform target language translation on textual content
    String translated;
    if (targetLanguage.toLowerCase() == 'english') {
      translated = _convertToEnglish(processed);
    } else if (targetLanguage.toLowerCase() == 'hindi') {
      translated = _convertToHindi(processed);
    } else {
      // Default to Hinglish
      translated = _convertToHinglish(processed);
    }

    // 3. Restore all preserved code blocks and inline code
    codeBlockPlaceholders.forEach((placeholder, originalCode) {
      translated = translated.replaceAll(placeholder, originalCode);
    });

    return translated;
  }

  /// Translates text into clear, academic English
  String _convertToEnglish(String text) {
    String res = text;

    // Common Greetings & Introductory lines
    res = res.replaceAll(RegExp(r'Arrey Namaste! Kaise (?:hain aap|ho beta)\? Main hoon (?:aapki|aapka|tumhara)', caseSensitive: false), 'Hello! How are you? I am your');
    res = res.replaceAll(RegExp(r'Arrey shabaash!', caseSensitive: false), 'Great job!');
    res = res.replaceAll(RegExp(r'Arrey zabardast!', caseSensitive: false), 'Fantastic!');
    res = res.replaceAll(RegExp(r'Arrey suno!', caseSensitive: false), 'Listen carefully!');
    res = res.replaceAll(RegExp(r'Arrey bohot shaandar question!', caseSensitive: false), 'Excellent and insightful question!');
    res = res.replaceAll(RegExp(r'Wah!', caseSensitive: false), 'Wonderful!');
    res = res.replaceAll(RegExp(r'Bohot badhiya!', caseSensitive: false), 'Very good!');
    res = res.replaceAll(RegExp(r'Shaandar!', caseSensitive: false), 'Brilliant!');
    res = res.replaceAll(RegExp(r'Bilkul!', caseSensitive: false), 'Certainly!');
    res = res.replaceAll(RegExp(r'Bahut badhiya aur thoughtful question poocha hai tumne:', caseSensitive: false), 'You have asked a very thoughtful and important question:');
    res = res.replaceAll(RegExp(r'Chalo bilkul crystal clear samjhein:', caseSensitive: false), 'Let us understand this crystal clear:');
    res = res.replaceAll(RegExp(r'Chalo is concept ko bilkul crystal clear, step-by-step tareeqe se samjhein:', caseSensitive: false), 'Let us break down this concept step-by-step with absolute clarity:');
    res = res.replaceAll(RegExp(r'Aao isse ek solid engineering perspective se todte hain:', caseSensitive: false), 'Let us analyze this from a solid engineering perspective:');

    // Section Headings
    res = res.replaceAll(RegExp(r'### 🏃 Analogy Se Samjho:', caseSensitive: false), '### 🏃 Conceptual Analogy:');
    res = res.replaceAll(RegExp(r'### 🏢 Real-World Analogy:', caseSensitive: false), '### 🏢 Real-World Analogy:');
    res = res.replaceAll(RegExp(r'### 💡 Core Concept:', caseSensitive: false), '### 💡 Core Concept:');
    res = res.replaceAll(RegExp(r'### 🎯 1\. Core Fundamental Concept:', caseSensitive: false), '### 🎯 1. Core Fundamental Concept:');
    res = res.replaceAll(RegExp(r'### 💡 2\. Real-World Analogy:', caseSensitive: false), '### 💡 2. Real-World Analogy:');
    res = res.replaceAll(RegExp(r'### ⚡ 3\. Step-by-Step Architecture & Mechanism:', caseSensitive: false), '### ⚡ 3. Step-by-Step Architecture & Mechanism:');
    res = res.replaceAll(RegExp(r'### 📝 4\. University Exam & Technical Interview Strategy:', caseSensitive: false), '### 📝 4. University Exam & Interview Strategy:');
    res = res.replaceAll(RegExp(r'### 🔍 Step-by-Step Logic in Go:', caseSensitive: false), '### 🔍 Step-by-Step Logic in Go:');
    res = res.replaceAll(RegExp(r'### 🔍 Step-by-Step Logic:', caseSensitive: false), '### 🔍 Step-by-Step Logic:');
    res = res.replaceAll(RegExp(r'### 🔍 Step-by-Step Dry Run', caseSensitive: false), '### 🔍 Step-by-Step Dry Run');
    res = res.replaceAll(RegExp(r'### ⚠️ Python Traps & Interview Tips:', caseSensitive: false), '### ⚠️ Python Traps & Interview Tips:');
    res = res.replaceAll(RegExp(r'### ⚠️ Exam Hacks & Common Mistakes:', caseSensitive: false), '### ⚠️ Exam Hacks & Common Mistakes:');
    res = res.replaceAll(RegExp(r'### 🎓 B\.Tech & Golang Interview Hack:', caseSensitive: false), '### 🎓 B.Tech & Golang Interview Tip:');
    res = res.replaceAll(RegExp(r'### 🎓 University Exam Hacks:', caseSensitive: false), '### 🎓 University Exam Insights:');
    res = res.replaceAll(RegExp(r'### 🎓 University Exam Hack:', caseSensitive: false), '### 🎓 University Exam Insight:');
    res = res.replaceAll(RegExp(r'### 🎓 Interview Viva Question:', caseSensitive: false), '### 🎓 Interview Viva Question:');
    res = res.replaceAll(RegExp(r'### 🎓 Java Viva Tips:', caseSensitive: false), '### 🎓 Java Viva Tips:');
    res = res.replaceAll(RegExp(r'### ⚡ C\+\+ Pro Tip:', caseSensitive: false), '### ⚡ C++ Pro Tip:');
    res = res.replaceAll(RegExp(r'### ⚠️ JS Pitfall:', caseSensitive: false), '### ⚠️ JavaScript Pitfall:');

    // Key technical and colloquial phrases
    res = res.replaceAll('Go mein `while` ya `do-while` keyword hota hi nahi hai!', 'In Go, there is no `while` or `do-while` keyword at all!');
    res = res.replaceAll('Go language ke andar har tarah ke loop ke liye sirf ek hi universal keyword hai: **`for`**!', 'In the Go language, there is only one universal keyword for every type of loop: **`for`**!');
    res = res.replaceAll('Socho tum college ke ground par **5 laps** daud rahe ho:', 'Imagine running **5 laps** around the college ground:');
    res = res.replaceAll('Socho tum college ground par **5 laps** daud rahe ho:', 'Imagine running **5 laps** around the college ground:');
    res = res.replaceAll('Lap count shuru hua 1 se', 'Lap count begins at 1');
    res = res.replaceAll('Har round ke baad check karo kya 5 complete hue?', 'After each round, check whether 5 laps are completed');
    res = res.replaceAll('Har lap ke baad counter +1 hoga', 'After each lap, the counter increments by +1');
    res = res.replaceAll('Increment bhoolna mat!', 'Do not forget to increment!');
    res = res.replaceAll('Kam se kam 1 baar zaroor chalega', 'Will execute at least once guaranteed');
    res = res.replaceAll('Best for fixed iterations', 'Best for a predetermined number of iterations');
    res = res.replaceAll('Entry-controlled loop', 'Entry-controlled loop');
    res = res.replaceAll('Exit-controlled', 'Exit-controlled');
    res = res.replaceAll('B.Tech first year practical aur theory dono ka sabse favourite question hai.', 'is a favorite question in both B.Tech practical and theory exams.');
    res = res.replaceAll('Viva question: *"Go language mein while loop kaise likhte hain?"*', 'Viva question: *"How do you write a while loop in Go?"*');
    res = res.replaceAll('Answer: *"Sir, Go mein while keyword nahi hota, `for condition { }` hi Go ka while loop hai!"* Full marks pakke!', 'Answer: *"Sir, Go does not have a while keyword; `for condition { }` itself acts as the while loop in Go!"* Full marks guaranteed!');
    res = res.replaceAll('Batao, kya sawal hai tumhara?', 'What topic would you like to explore today?');
    res = res.replaceAll('Main hoon tumhara B.Tech AI Professor.', 'I am your B.Tech AI Professor.');
    res = res.replaceAll('Aap exactly kis formula, syntax ya step par detail mein discuss karna chahte ho? Poochho, main step-by-step samjhata hoon!', 'Which specific formula, syntax, or step would you like to dive deeper into? Ask away, and I will explain step-by-step!');
    res = res.replaceAll('kaise kaam karta hai', 'how it works');
    res = res.replaceAll('kaise kaam karti hai', 'how it works');
    res = res.replaceAll('dhyan se samjho', 'understand carefully');
    res = res.replaceAll('dhyan se dekho', 'observe carefully');
    res = res.replaceAll('dhyan se', 'carefully');
    res = res.replaceAll('samajh lo', 'understand');
    res = res.replaceAll('samjhein', 'understand');
    res = res.replaceAll('samjhata hoon', 'I will explain');
    res = res.replaceAll('samjho', 'understand');
    res = res.replaceAll('poocho', 'ask');
    res = res.replaceAll('poochho', 'ask');
    res = res.replaceAll('shuru karte hain', 'let us begin');
    res = res.replaceAll('yaad rakhna', 'remember');
    res = res.replaceAll('yaad rakho', 'remember');
    res = res.replaceAll('yahan par', 'here');
    res = res.replaceAll('iske baad', 'after this');
    res = res.replaceAll('sabse pehle', 'first of all');
    res = res.replaceAll('pehle', 'first');
    res = res.replaceAll('hota hai', 'is');
    res = res.replaceAll('hoti hai', 'is');
    res = res.replaceAll('hote hain', 'are');
    res = res.replaceAll('karte hain', 'we do');
    res = res.replaceAll('karta hai', 'does');
    res = res.replaceAll('karti hai', 'does');
    res = res.replaceAll('karenge', 'we will do');
    res = res.replaceAll('karega', 'will do');
    res = res.replaceAll('chahiye', 'is required');
    res = res.replaceAll('bina kisi doubt ke', 'without any doubt');
    res = res.replaceAll('pakka', 'guaranteed');
    res = res.replaceAll('fayda', 'benefit');
    res = res.replaceAll('nuksan', 'drawback');
    res = res.replaceAll('karan', 'reason');
    res = res.replaceAll('kuch is tarah', 'in this manner');
    res = res.replaceAll('is tarah se', 'in this way');
    res = res.replaceAll('iske do fayde hain', 'it has two key benefits');
    res = res.replaceAll('college mein', 'in college');
    res = res.replaceAll('exam mein', 'in the exam');
    res = res.replaceAll('interview mein', 'in the interview');
    res = res.replaceAll('viva mein', 'in viva exams');

    return res;
  }

  /// Translates text into clean Hindi (Devanagari script)
  String _convertToHindi(String text) {
    String res = text;

    // English technical phrases into Hindi
    res = res.replaceAll(RegExp(r'\bThe expression\b', caseSensitive: false), 'यह व्यंजक');
    res = res.replaceAll(RegExp(r'\bis asking for\b', caseSensitive: false), 'पूछ रहा है');
    res = res.replaceAll(RegExp(r'\binverse sine\b', caseSensitive: false), 'व्युत्क्रम ज्या');
    res = res.replaceAll(RegExp(r'\blogarithm of\b', caseSensitive: false), 'लघुगणक');
    res = res.replaceAll(RegExp(r"Let's break this down step by step:?", caseSensitive: false), 'आइए इसे चरण-दर-चरण समझें:');
    res = res.replaceAll(RegExp(r'\bstep by step\b', caseSensitive: false), 'चरण-दर-चरण');
    res = res.replaceAll(RegExp(r'\bThis means that\b', caseSensitive: false), 'इसका अर्थ है कि');
    res = res.replaceAll(RegExp(r'\bTherefore, the expression\b', caseSensitive: false), 'अतः यह व्यंजक');

    // Common Greetings & Introductory lines
    res = res.replaceAll(RegExp(r'Arrey Namaste! Kaise (?:hain aap|ho beta)\? Main hoon (?:aapki|aapka|tumhara)', caseSensitive: false), 'नमस्ते! आप कैसे हैं? मैं हूँ आपकी');
    res = res.replaceAll(RegExp(r'Arrey shabaash!', caseSensitive: false), 'शाबाश!');
    res = res.replaceAll(RegExp(r'Arrey zabardast!', caseSensitive: false), 'बहुत बढ़िया!');
    res = res.replaceAll(RegExp(r'Arrey suno!', caseSensitive: false), 'ध्यान से सुनो!');
    res = res.replaceAll(RegExp(r'Arrey bohot shaandar question!', caseSensitive: false), 'बहुत ही शानदार और महत्वपूर्ण प्रश्न!');
    res = res.replaceAll(RegExp(r'Wah!', caseSensitive: false), 'वाह!');
    res = res.replaceAll(RegExp(r'Bohot badhiya!', caseSensitive: false), 'अति उत्तम!');
    res = res.replaceAll(RegExp(r'Shaandar!', caseSensitive: false), 'शानदार!');
    res = res.replaceAll(RegExp(r'Bilkul!', caseSensitive: false), 'बिल्कुल!');
    res = res.replaceAll(RegExp(r'Bahut badhiya aur thoughtful question poocha hai tumne:', caseSensitive: false), 'आपने बहुत ही गहरा और विचारणीय प्रश्न पूछा है:');
    res = res.replaceAll(RegExp(r'Chalo bilkul crystal clear samjhein:', caseSensitive: false), 'आइए इसे पूरी तरह स्पष्ट रूप से समझें:');
    res = res.replaceAll(RegExp(r'Chalo is concept ko bilkul crystal clear, step-by-step tareeqe se samjhein:', caseSensitive: false), 'आइए इस अवधारणा को चरण-दर-चरण स्पष्टता के साथ समझें:');
    res = res.replaceAll(RegExp(r'Aao isse ek solid engineering perspective se todte hain:', caseSensitive: false), 'आइए इसे एक ठोस इंजीनियरिंग दृष्टिकोण से विश्लेषित करें:');

    // Section Headings
    res = res.replaceAll(RegExp(r'### 🏃 Analogy Se Samjho:', caseSensitive: false), '### 🏃 सादृश्य और उदाहरण से समझें:');
    res = res.replaceAll(RegExp(r'### 🏢 Real-World Analogy:', caseSensitive: false), '### 🏢 वास्तविक जीवन का उदाहरण:');
    res = res.replaceAll(RegExp(r'### 💡 Core Concept:', caseSensitive: false), '### 💡 मुख्य अवधारणा (Core Concept):');
    res = res.replaceAll(RegExp(r'### 🎯 1\. Core Fundamental Concept:', caseSensitive: false), '### 🎯 1. मुख्य मूलभूत अवधारणा:');
    res = res.replaceAll(RegExp(r'### 💡 2\. Real-World Analogy:', caseSensitive: false), '### 💡 2. व्यावहारिक सादृश्य:');
    res = res.replaceAll(RegExp(r'### ⚡ 3\. Step-by-Step Architecture & Mechanism:', caseSensitive: false), '### ⚡ 3. चरण-दर-चरण संरचना व तंत्र:');
    res = res.replaceAll(RegExp(r'### 📝 4\. University Exam & Technical Interview Strategy:', caseSensitive: false), '### 📝 4. विश्वविद्यालय परीक्षा व साक्षात्कार रणनीति:');
    res = res.replaceAll(RegExp(r'### 🔍 Step-by-Step Logic in Go:', caseSensitive: false), '### 🔍 Go भाषा में चरण-दर-चरण तर्क:');
    res = res.replaceAll(RegExp(r'### 🔍 Step-by-Step Logic:', caseSensitive: false), '### 🔍 चरण-दर-चरण तर्क:');
    res = res.replaceAll(RegExp(r'### 🔍 Step-by-Step Dry Run', caseSensitive: false), '### 🔍 चरण-दर-चरण ड्राय रन');
    res = res.replaceAll(RegExp(r'### ⚠️ Python Traps & Interview Tips:', caseSensitive: false), '### ⚠️ पाइथन सावधानियां व इंटरव्यू युक्तियाँ:');
    res = res.replaceAll(RegExp(r'### ⚠️ Exam Hacks & Common Mistakes:', caseSensitive: false), '### ⚠️ परीक्षा युक्तियाँ व सामान्य गलतियाँ:');
    res = res.replaceAll(RegExp(r'### 🎓 B\.Tech & Golang Interview Hack:', caseSensitive: false), '### 🎓 बी.टेक व गो इंटरव्यू युक्तियाँ:');
    res = res.replaceAll(RegExp(r'### 🎓 University Exam Hacks:', caseSensitive: false), '### 🎓 विश्वविद्यालय परीक्षा युक्तियाँ:');
    res = res.replaceAll(RegExp(r'### 🎓 University Exam Hack:', caseSensitive: false), '### 🎓 परीक्षा महत्वपूर्ण बिंदु:');
    res = res.replaceAll(RegExp(r'### 🎓 Interview Viva Question:', caseSensitive: false), '### 🎓 वायवा (Viva) प्रश्न:');
    res = res.replaceAll(RegExp(r'### 🎓 Java Viva Tips:', caseSensitive: false), '### 🎓 जावा वायवा युक्तियाँ:');
    res = res.replaceAll(RegExp(r'### ⚡ C\+\+ Pro Tip:', caseSensitive: false), '### ⚡ C++ महत्वपूर्ण टिप:');
    res = res.replaceAll(RegExp(r'### ⚠️ JS Pitfall:', caseSensitive: false), '### ⚠️ जावास्क्रिप्ट सावधानी:');

    // Key technical and colloquial phrases
    res = res.replaceAll('Go mein `while` ya `do-while` keyword hota hi nahi hai!', 'Go भाषा में `while` या `do-while` कीवर्ड होता ही नहीं है!');
    res = res.replaceAll('Go language ke andar har tarah ke loop ke liye sirf ek hi universal keyword hai: **`for`**!', 'Go भाषा के अंदर हर प्रकार के लूप के लिए केवल एक ही मुख्य कीवर्ड है: **`for`**!');
    res = res.replaceAll('Socho tum college ke ground par **5 laps** daud rahe ho:', 'सोचिए आप कॉलेज के मैदान पर **5 चक्कर (laps)** दौड़ रहे हैं:');
    res = res.replaceAll('Socho tum college ground par **5 laps** daud rahe ho:', 'सोचिए आप कॉलेज के मैदान पर **5 चक्कर (laps)** दौड़ रहे हैं:');
    res = res.replaceAll('Lap count shuru hua 1 se', 'चक्कर की गिनती 1 से शुरू हुई');
    res = res.replaceAll('Har round ke baad check karo kya 5 complete hue?', 'प्रत्येक राउंड के बाद जांचें क्या 5 चक्कर पूरे हुए?');
    res = res.replaceAll('Har lap ke baad counter +1 hoga', 'प्रत्येक राउंड के बाद काउंटर +1 बढ़ेगा');
    res = res.replaceAll('Increment bhoolna mat!', 'काउंटर बढ़ाना मत भूलना!');
    res = res.replaceAll('Kam se kam 1 baar zaroor chalega', 'कम से कम 1 बार अवश्य चलेगा');
    res = res.replaceAll('Best for fixed iterations', 'निश्चित पुनरावृत्तियों के लिए सर्वोत्तम');
    res = res.replaceAll('B.Tech first year practical aur theory dono ka sabse favourite question hai.', 'बी.टेक प्रथम वर्ष के प्रैक्टिकल और थ्योरी दोनों का अत्यंत प्रिय प्रश्न है।');
    res = res.replaceAll('Viva question: *"Go language mein while loop kaise likhte hain?"*', 'वायवा प्रश्न: *"Go भाषा में while loop कैसे लिखते हैं?"*');
    res = res.replaceAll('Answer: *"Sir, Go mein while keyword nahi hota, `for condition { }` hi Go ka while loop hai!"* Full marks pakke!', 'उत्तर: *"सर, Go में while कीवर्ड नहीं होता, `for condition { }` ही Go का while लूप है!"* पूरे अंक पक्के!');
    res = res.replaceAll('Batao, kya sawal hai tumhara?', 'बताइए, आपका क्या प्रश्न है?');
    res = res.replaceAll(RegExp(r'Main hoon (?:tumhara|aapka|aapki) B\.Tech (?:AI )?Professor\.', caseSensitive: false), 'मैं हूँ आपकी बी.टेक एआई प्रोफेसर।');
    res = res.replaceAll('Aap exactly kis formula, syntax ya step par detail mein discuss karna chahte ho? Poochho, main step-by-step samjhata hoon!', 'आप किस सूत्र, सिंटेक्स या चरण पर विस्तार से चर्चा करना चाहते हैं? पूछिए, हम चरण-दर-चरण समझाएंगे!');
    res = res.replaceAll('kaise kaam karta hai', 'कैसे कार्य करता है');
    res = res.replaceAll('kaise kaam karti hai', 'कैसे कार्य करती है');
    res = res.replaceAll('dhyan se samjho', 'ध्यान से समझें');
    res = res.replaceAll('dhyan se dekho', 'ध्यान से देखें');
    res = res.replaceAll('dhyan se', 'ध्यानपूर्वक');
    res = res.replaceAll('samajh lo', 'समझ लीजिए');
    res = res.replaceAll('samjhein', 'समझें');
    res = res.replaceAll('samjhata hoon', 'समझते हैं');
    res = res.replaceAll('samjho', 'समझें');
    res = res.replaceAll('poocho', 'पूछिए');
    res = res.replaceAll('poochho', 'पूछिए');
    res = res.replaceAll('shuru karte hain', 'शुरू करते हैं');
    res = res.replaceAll('yaad rakhna', 'याद रखें');
    res = res.replaceAll('yaad rakho', 'याद रखें');
    res = res.replaceAll('yahan par', 'यहाँ पर');
    res = res.replaceAll('iske baad', 'इसके पश्चात');
    res = res.replaceAll('sabse pehle', 'सर्वप्रथम');
    res = res.replaceAll('pehle', 'पहले');
    res = res.replaceAll('hota hai', 'होता है');
    res = res.replaceAll('hoti hai', 'होती है');
    res = res.replaceAll('hote hain', 'होते हैं');
    res = res.replaceAll('karte hain', 'करते हैं');
    res = res.replaceAll('karta hai', 'करता है');
    res = res.replaceAll('karti hai', 'करती है');
    res = res.replaceAll('karenge', 'करेंगे');
    res = res.replaceAll('karega', 'करेगा');
    res = res.replaceAll('chahiye', 'चाहिए');
    res = res.replaceAll('bina kisi doubt ke', 'बिना किसी संशय के');
    res = res.replaceAll('pakka', 'निश्चित');
    res = res.replaceAll('fayda', 'लाभ');
    res = res.replaceAll('nuksan', 'हानि');
    res = res.replaceAll('karan', 'कारण');
    res = res.replaceAll('kuch is tarah', 'कुछ इस प्रकार');
    res = res.replaceAll('is tarah se', 'इस प्रकार से');
    res = res.replaceAll('iske do fayde hain', 'इसके दो प्रमुख लाभ हैं');
    res = res.replaceAll('college mein', 'कॉलेज में');
    res = res.replaceAll('exam mein', 'परीक्षा में');
    res = res.replaceAll('interview mein', 'साक्षात्कार में');
    res = res.replaceAll('viva mein', 'वायवा में');

    return res;
  }

  /// Converts formal technical English into natural conversational B.Tech Hinglish
  String _convertToHinglish(String text) {
    String res = text;

    final englishToHinglishPatterns = {
      RegExp(r"Let's break this down step by step:?", caseSensitive: false): 'Chalo isse step-by-step crystal clear samjhein:',
      RegExp(r"Let's start by understanding each part:?", caseSensitive: false): 'Chalo pehle har part ko detail mein samjhein:',
      RegExp(r"Let's find the derivative of", caseSensitive: false): 'Chalo derivative calculate karte hain:',
      RegExp(r"Using the power rule,? the derivative is", caseSensitive: false): 'Power rule use karte hue derivative hoga:',
      RegExp(r"Using the power rule", caseSensitive: false): 'Power rule use karte hue',
      RegExp(r"The derivative of a constant is zero\.?", caseSensitive: false): 'Kisi bhi constant ka derivative zero hota hai.',
      RegExp(r"is asking for the inverse sine of", caseSensitive: false): 'mein hume inverse sine nikalna hai',
      RegExp(r"is asking for", caseSensitive: false): 'mein hume calculate karna hai',
      RegExp(r"Initialize the variable:?", caseSensitive: false): 'Variable initialize karein:',
      RegExp(r"Loop through the range:?", caseSensitive: false): 'Range par loop chalayein:',
      RegExp(r"Add each number to the sum:?", caseSensitive: false): 'Har number ko sum mein add karein:',
      RegExp(r"Print the result:?", caseSensitive: false): 'Result print karein:',
      RegExp(r"When you run this program,? it will output:?", caseSensitive: false): 'Jab aap yeh program run karenge, toh output aayega:',
      RegExp(r"This is a simple example of", caseSensitive: false): 'Yeh ek simple example hai',
      RegExp(r"In each iteration of the loop", caseSensitive: false): 'Loop ke har iteration mein',
      RegExp(r"Finally,? we print the total sum", caseSensitive: false): 'Finally, hum total sum print kar dete hain',
      RegExp(r"The logarithm of 10 to any base is 1\.?", caseSensitive: false): 'Kisi bhi base par 10 ka logarithm 1 hota hai.',
      RegExp(r"Therefore,? the expression", caseSensitive: false): 'Isliye expression',
      RegExp(r"simplifies to:?", caseSensitive: false): 'simplify hokar banega:',
      RegExp(r"This means that the value of", caseSensitive: false): 'Iska matlab hai ki',
      RegExp(r"Step 1: Identify the Function", caseSensitive: false): 'Step 1: Function identify karein',
      RegExp(r"Step 2: Apply the Rules of Differentiation", caseSensitive: false): 'Step 2: Differentiation rules apply karein',
      RegExp(r"Step 3: Apply the Rules", caseSensitive: false): 'Step 3: Rules apply karein',
      RegExp(r"Step 4: Simplify Further", caseSensitive: false): 'Step 4: Further simplify karein',
      RegExp(r"Combine like terms:?", caseSensitive: false): 'Like terms ko combine karein:',
    };

    englishToHinglishPatterns.forEach((pattern, replacement) {
      res = res.replaceAll(pattern, replacement);
    });

    return res;
  }
}
