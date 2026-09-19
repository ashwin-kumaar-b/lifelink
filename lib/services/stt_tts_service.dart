import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'local_storage_service.dart';

class SttTtsService {
  static final SttTtsService _instance = SttTtsService._internal();
  factory SttTtsService() => _instance;
  SttTtsService._internal();

  sherpa_onnx.OfflineRecognizer? _sttRecognizer;
  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isSttInitialized = false;
  bool _isTtsInitialized = false;
  bool _isRecording = false;
  bool _isSttLoading = false;
  String _loadedLanguage = '';

  bool get isSttReady => _isSttInitialized && _sttRecognizer != null;
  bool get isSttLoading => _isSttLoading;
  bool get isTtsReady => _isTtsInitialized;
  bool get isRecording => _isRecording;

  final List<String> emergencyKeywords = [
    'emergency',
    'floods',
    'flood',
    'disaster',
    'help',
    'sos',
    'rescue',
    'medical',
    'fire',
    'trapped',
    'tsunami',
    'earthquake',
    'cyclone',
  ];

  Future<void> initialize({String? language}) async {
    try {
      sherpa_onnx.initBindings();
    } catch (e) {
      debugPrint('Sherpa-ONNX initBindings notice: $e');
    }

    final targetLang = language ?? await LocalStorageService().getPreferredLanguage();
    await loadModelForLanguage(targetLang);

    // Initialize Android System Native Text-To-Speech (TTS)
    try {
      final ttsLocale = _mapToFullLocale(targetLang);
      await _flutterTts.setLanguage(ttsLocale);
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
      debugPrint('Android Native System TTS initialized with $ttsLocale');
    } catch (e) {
      debugPrint('Android Native TTS Init Exception: $e');
    }
  }

  Future<bool> loadModelForLanguage(String languageCode) async {
    final langTag = languageCode.toLowerCase().trim();
    if (_isSttInitialized && _loadedLanguage == langTag && _sttRecognizer != null) {
      return true;
    }

    _isSttLoading = true;
    try {
      // Free previous recognizer instance if switching to a new language
      if (_sttRecognizer != null && _loadedLanguage != langTag) {
        debugPrint('Freeing previous STT Recognizer instance [$_loadedLanguage] before loading [$langTag]...');
        try {
          _sttRecognizer?.free();
        } catch (e) {
          debugPrint('Error freeing previous STT recognizer: $e');
        }
        _sttRecognizer = null;
        _isSttInitialized = false;
      }

      // 0. Dedicated Single-File CTC Models (Telugu, Hindi, Tamil, English)
      if (langTag == 'te' || langTag == 'hi' || langTag == 'ta' || langTag == 'en') {
        final success = await _loadNativeIndicModel(langTag);
        if (success) return true;
      }

      final docDir = await getApplicationDocumentsDirectory();

      // 1. Attempt to load Multilingual Whisper Base INT8 Model
      try {
        final sttDir = Directory('${docDir.path}/models/multilingual');
        if (!await sttDir.exists()) await sttDir.create(recursive: true);

        final encoderPath = await _copyAssetToLocal(
          'assets/models/base-encoder.int8.onnx',
          '${sttDir.path}/base-encoder.int8.onnx',
        );
        final decoderPath = await _copyAssetToLocal(
          'assets/models/base-decoder.int8.onnx',
          '${sttDir.path}/base-decoder.int8.onnx',
        );
        final tokensPath = await _copyAssetToLocal(
          'assets/models/base-tokens.txt',
          '${sttDir.path}/base-tokens.txt',
        );

        if (encoderPath != null && decoderPath != null && tokensPath != null) {
          final sttConfig = sherpa_onnx.OfflineRecognizerConfig(
            model: sherpa_onnx.OfflineModelConfig(
              whisper: sherpa_onnx.OfflineWhisperModelConfig(
                encoder: encoderPath,
                decoder: decoderPath,
                language: langTag, // 'ta', 'te', 'en', 'hi', etc.
                task: 'transcribe',
              ),
              tokens: tokensPath,
              numThreads: 2,
              debug: false,
            ),
          );
          _sttRecognizer = sherpa_onnx.OfflineRecognizer(sttConfig);
          _isSttInitialized = true;
          _loadedLanguage = langTag;
          debugPrint('Sherpa-ONNX Multilingual STT Model loaded successfully for [$langTag]!');
          return true;
        }
      } catch (e) {
        debugPrint('Sherpa-ONNX Multilingual STT Load Error: $e');
      }

      // 2. Fallback to English Model if Multilingual asset is missing
      return await _loadEnglishFallbackModel();
    } finally {
      _isSttLoading = false;
    }
  }

  Future<bool> _loadNativeIndicModel(String lang) async {
    try {
      final langNameMap = {'te': 'telugu', 'hi': 'hindi', 'ta': 'tamil', 'en': 'english'};
      final fullLang = langNameMap[lang] ?? lang;

      final docDir = await getApplicationDocumentsDirectory();
      final sttDir = Directory('${docDir.path}/models/$fullLang');
      if (!await sttDir.exists()) await sttDir.create(recursive: true);

      String? modelPath;
      String? tokensPath;

      final localNamedFile = File('${sttDir.path}/${fullLang}_model.int8.onnx');
      final localModelFile = File('${sttDir.path}/model.int8.onnx');
      final localTokensFile = File('${sttDir.path}/tokens.txt');

      if (await localNamedFile.exists() && await localTokensFile.exists()) {
        modelPath = localNamedFile.path;
        tokensPath = localTokensFile.path;
        debugPrint('Using downloaded native [$lang] model [${localNamedFile.path}] from local storage.');
      } else if (await localModelFile.exists() && await localTokensFile.exists()) {
        modelPath = localModelFile.path;
        tokensPath = localTokensFile.path;
        debugPrint('Using downloaded native [$lang] model from local storage.');
      } else {
        modelPath = await _copyAssetToLocal(
          'assets/models/$fullLang/${fullLang}_model.int8.onnx',
          '${sttDir.path}/${fullLang}_model.int8.onnx',
        ) ?? await _copyAssetToLocal(
          'assets/models/$fullLang/model.int8.onnx',
          '${sttDir.path}/model.int8.onnx',
        );
        tokensPath = await _copyAssetToLocal(
          'assets/models/$fullLang/tokens.txt',
          '${sttDir.path}/tokens.txt',
        );
      }

      if (modelPath != null && tokensPath != null) {
        final sttConfig = sherpa_onnx.OfflineRecognizerConfig(
          model: sherpa_onnx.OfflineModelConfig(
            nemoCtc: sherpa_onnx.OfflineNemoEncDecCtcModelConfig(
              model: modelPath,
            ),
            tokens: tokensPath,
            numThreads: 2,
            debug: false,
          ),
        );
        _sttRecognizer = sherpa_onnx.OfflineRecognizer(sttConfig);
        _isSttInitialized = true;
        _loadedLanguage = lang;
        debugPrint('Sherpa-ONNX Dedicated Native [$lang] IndicConformer STT Model loaded successfully!');
        return true;
      }
    } catch (e) {
      debugPrint('Sherpa-ONNX Dedicated [$lang] STT Load Error: $e');
    }
    return false;
  }

  Future<bool> _loadEnglishFallbackModel() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final sttDir = Directory('${docDir.path}/models/english');
      if (!await sttDir.exists()) await sttDir.create(recursive: true);

      final modelPath = await _copyAssetToLocal(
        'assets/models/english/model.int8.onnx',
        '${sttDir.path}/model.int8.onnx',
      );
      final tokensPath = await _copyAssetToLocal(
        'assets/models/english/tokens.txt',
        '${sttDir.path}/tokens.txt',
      );

      if (modelPath != null && tokensPath != null) {
        final sttConfig = sherpa_onnx.OfflineRecognizerConfig(
          model: sherpa_onnx.OfflineModelConfig(
            nemoCtc: sherpa_onnx.OfflineNemoEncDecCtcModelConfig(
              model: modelPath,
            ),
            tokens: tokensPath,
            numThreads: 2,
            debug: false,
          ),
        );
        _sttRecognizer = sherpa_onnx.OfflineRecognizer(sttConfig);
        _isSttInitialized = true;
        _loadedLanguage = 'en';
        debugPrint('Sherpa-ONNX English Pre-Installed Single-File CTC Model loaded successfully!');
        return true;
      }
    } catch (e) {
      debugPrint('English fallback load exception: $e');
    }
    return false;
  }

  Future<String?> _copyAssetToLocal(String assetPath, String localPath) async {
    try {
      final file = File(localPath);
      final data = await rootBundle.load(assetPath);
      final int assetLength = data.lengthInBytes;

      if (await file.exists() && await file.length() == assetLength) {
        return localPath;
      }

      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return localPath;
    } catch (e) {
      debugPrint('Error copying asset $assetPath: $e');
      return null;
    }
  }

  Future<bool> startRecording() async {
    if (!await _audioRecorder.hasPermission()) {
      debugPrint('Microphone permission not granted.');
      return false;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final wavPath = '${tempDir.path}/lifelink_recorded_input.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: wavPath,
      );
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('Start recording error: $e');
      _isRecording = false;
      return false;
    }
  }

  Future<String> stopAndTranscribe() async {
    if (!_isRecording) return '';

    try {
      final wavPath = await _audioRecorder.stop();
      _isRecording = false;

      if (wavPath == null || !File(wavPath).existsSync()) return '';
      if (_sttRecognizer == null) return '';

      final wave = sherpa_onnx.readWave(wavPath);
      final Float32List samples = _resampleTo16k(wave.samples, wave.sampleRate);
      final Float32List cleanSamples = _trimSilence(samples);

      final stream = _sttRecognizer!.createStream();
      stream.acceptWaveform(samples: cleanSamples, sampleRate: 16000);
      _sttRecognizer!.decode(stream);
      final result = _sttRecognizer!.getResult(stream);

      final rawText = result.text.trim();
      final sanitizedText = _cleanTranscriptForLanguage(rawText, _loadedLanguage);
      return sanitizedText;
    } catch (e) {
      debugPrint('STT Decoding Error: $e');
      _isRecording = false;
      return '';
    }
  }

  Float32List _trimSilence(Float32List samples, {double threshold = 0.012}) {
    if (samples.isEmpty) return samples;
    int start = 0;
    while (start < samples.length && samples[start].abs() < threshold) {
      start++;
    }
    int end = samples.length - 1;
    while (end > start && samples[end].abs() < threshold) {
      end--;
    }

    if (start >= end) return samples;

    final paddedStart = (start - 800).clamp(0, samples.length);
    final paddedEnd = (end + 800).clamp(0, samples.length);

    return samples.sublist(paddedStart, paddedEnd);
  }

  String _cleanTranscriptForLanguage(String rawText, String languageCode) {
    if (rawText.isEmpty) return rawText;

    // Filter out hallucinated Arabic/Persian/Urdu (\u0600-\u06FF) & Cyrillic/CJK BPE tokens
    String cleaned = rawText.replaceAll(
      RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\u0400-\u04FF\u4E00-\u9FFF]'),
      '',
    );

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  Float32List _resampleTo16k(Float32List inputSamples, int inputRate) {
    if (inputRate == 16000 || inputRate <= 0) return inputSamples;
    final double ratio = 16000.0 / inputRate;
    final int outputLength = (inputSamples.length * ratio).floor();
    final Float32List output = Float32List(outputLength);
    for (int i = 0; i < outputLength; i++) {
      final double srcIndex = i / ratio;
      final int index = srcIndex.floor();
      final double frac = srcIndex - index;
      if (index + 1 < inputSamples.length) {
        output[i] = inputSamples[index] * (1 - frac) + inputSamples[index + 1] * frac;
      } else if (index < inputSamples.length) {
        output[i] = inputSamples[index];
      }
    }
    return output;
  }

  String? checkEmergencyKeyword(String text) {
    if (text.isEmpty) return null;
    final lowerText = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final words = lowerText.split(RegExp(r'\s+'));

    for (final kw in emergencyKeywords) {
      if (lowerText.contains(kw)) {
        return kw.toUpperCase();
      }
    }

    for (final word in words) {
      if (word.length < 3) continue;
      for (final kw in emergencyKeywords) {
        if (word.startsWith(kw) || kw.startsWith(word) || _levenshteinDistance(word, kw) <= 2) {
          return kw.toUpperCase();
        }
      }
    }

    return null;
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(
            (curr, next) => curr < next ? curr : next);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  Future<void> speak(String text, {String language = 'en-US'}) async {
    if (text.isEmpty) return;
    try {
      await _flutterTts.stop();
      final targetLocale = _mapToFullLocale(language);
      await _flutterTts.setLanguage(targetLocale);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS Speak Error: $e');
    }
  }

  String _mapToFullLocale(String lang) {
    switch (lang.toLowerCase()) {
      case 'ta':
      case 'ta-in':
        return 'ta-IN';
      case 'te':
      case 'te-in':
        return 'te-IN';
      case 'hi':
      case 'hi-in':
        return 'hi-IN';
      case 'kn':
      case 'kn-in':
        return 'kn-IN';
      case 'ml':
      case 'ml-in':
        return 'ml-IN';
      case 'bn':
      case 'bn-in':
        return 'bn-IN';
      case 'mr':
      case 'mr-in':
        return 'mr-IN';
      case 'gu':
      case 'gu-in':
        return 'gu-IN';
      case 'en':
      case 'en-us':
      case 'en-in':
        return 'en-US';
      default:
        return lang.contains('-') ? lang : '$lang-IN';
    }
  }

  Future<void> stopTts() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS Stop Error: $e');
    }
  }
}
