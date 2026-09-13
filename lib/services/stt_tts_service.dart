import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';

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

  bool get isSttReady => _isSttInitialized && _sttRecognizer != null;
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

  Future<void> initialize() async {
    if (_isSttInitialized && _isTtsInitialized) return;

    try {
      sherpa_onnx.initBindings();
    } catch (e) {
      debugPrint('Sherpa-ONNX initBindings notice: $e');
    }

    final docDir = await getApplicationDocumentsDirectory();

    // 1. Copy & Initialize English STT Model (Whisper Tiny INT8)
    try {
      final sttDir = Directory('${docDir.path}/models/english');
      if (!await sttDir.exists()) await sttDir.create(recursive: true);

      final encoderPath = await _copyAssetToLocal(
        'assets/models/english/tiny.en-encoder.int8.onnx',
        '${sttDir.path}/encoder.onnx',
      );
      final decoderPath = await _copyAssetToLocal(
        'assets/models/english/tiny.en-decoder.int8.onnx',
        '${sttDir.path}/decoder.onnx',
      );
      final tokensPath = await _copyAssetToLocal(
        'assets/models/english/tiny.en-tokens.txt',
        '${sttDir.path}/tokens.txt',
      );

      if (encoderPath != null && decoderPath != null && tokensPath != null) {
        final sttConfig = sherpa_onnx.OfflineRecognizerConfig(
          model: sherpa_onnx.OfflineModelConfig(
            whisper: sherpa_onnx.OfflineWhisperModelConfig(
              encoder: encoderPath,
              decoder: decoderPath,
              language: 'en',
              task: 'transcribe',
            ),
            tokens: tokensPath,
            numThreads: 2,
            debug: false,
          ),
        );
        _sttRecognizer = sherpa_onnx.OfflineRecognizer(sttConfig);
        _isSttInitialized = true;
        debugPrint('Sherpa-ONNX English STT Engine initialized successfully!');
      }
    } catch (e) {
      debugPrint('Sherpa-ONNX STT Init Exception: $e');
    }

    // 2. Initialize Android System Native Text-To-Speech (TTS)
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
      debugPrint('Android Native System TTS initialized successfully!');
    } catch (e) {
      debugPrint('Android Native TTS Init Exception: $e');
    }
  }

  Future<String?> _copyAssetToLocal(String assetPath, String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists() && await file.length() > 0) {
        return localPath;
      }
      final data = await rootBundle.load(assetPath);
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

      final stream = _sttRecognizer!.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      _sttRecognizer!.decode(stream);
      final result = _sttRecognizer!.getResult(stream);

      return result.text.trim();
    } catch (e) {
      debugPrint('STT Decoding Error: $e');
      _isRecording = false;
      return '';
    }
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

    // 1. Exact or Substring match
    for (final kw in emergencyKeywords) {
      if (lowerText.contains(kw)) {
        return kw.toUpperCase();
      }
    }

    // 2. Fuzzy Stem / Levenshtein Distance match (<= 2)
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
      await _flutterTts.setLanguage(language);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS Speak Error: $e');
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
