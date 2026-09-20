enum SpeechModelArchitecture {
  nemoCtc,
  zipformerCtc,
  whisper,
}

class SpeechModelConfig {
  final String languageCode;
  final String fullLanguageName;
  final String modelFileName;
  final String tokensFileName;
  final SpeechModelArchitecture architecture;

  const SpeechModelConfig({
    required this.languageCode,
    required this.fullLanguageName,
    required this.modelFileName,
    required this.tokensFileName,
    required this.architecture,
  });
}

class SpeechModelRegistry {
  static const Map<String, SpeechModelConfig> _registry = {
    'en': SpeechModelConfig(
      languageCode: 'en',
      fullLanguageName: 'english',
      modelFileName: 'model.int8.onnx',
      tokensFileName: 'tokens.txt',
      architecture: SpeechModelArchitecture.nemoCtc,
    ),
    'hi': SpeechModelConfig(
      languageCode: 'hi',
      fullLanguageName: 'hindi',
      modelFileName: 'hindi_model.int8.onnx',
      tokensFileName: 'hindi_tokens.txt',
      architecture: SpeechModelArchitecture.nemoCtc,
    ),
    'te': SpeechModelConfig(
      languageCode: 'te',
      fullLanguageName: 'telugu',
      modelFileName: 'telugu_model.int8.onnx',
      tokensFileName: 'telugu_tokens.txt',
      architecture: SpeechModelArchitecture.nemoCtc,
    ),
    'ta': SpeechModelConfig(
      languageCode: 'ta',
      fullLanguageName: 'tamil',
      modelFileName: 'tamil_model.int8.onnx',
      tokensFileName: 'tamil_tokens.txt',
      architecture: SpeechModelArchitecture.nemoCtc,
    ),
  };

  static SpeechModelConfig getConfig(String languageCode) {
    final langTag = languageCode.toLowerCase().trim();
    return _registry[langTag] ?? _registry['en']!;
  }

  static bool isSupported(String languageCode) {
    return _registry.containsKey(languageCode.toLowerCase().trim());
  }
}
