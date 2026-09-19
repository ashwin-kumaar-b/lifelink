import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef DownloadProgressCallback = void Function(int receivedBytes, int totalBytes, double progressPercent);

class ModelDownloaderService {
  static final ModelDownloaderService _instance = ModelDownloaderService._internal();
  factory ModelDownloaderService() => _instance;
  ModelDownloaderService._internal();

  static const String githubReleaseBaseUrl =
      'https://github.com/devesh-54/jeevalink-speech-models/releases/download/v1.0.0/';

  final Map<String, String> _languageModelFileName = {
    'te': 'telugu_model.int8.onnx',
    'hi': 'hindi_model.int8.onnx',
    'ta': 'tamil_model.int8.onnx',
  };

  /// Checks if the model file and tokens.txt already exist locally for the given language.
  Future<bool> isModelDownloaded(String languageCode) async {
    final langTag = languageCode.toLowerCase().trim();
    if (langTag == 'en') return true; // English is pre-packaged default

    final langNameMap = {'te': 'telugu', 'hi': 'hindi', 'ta': 'tamil'};
    final fullLang = langNameMap[langTag] ?? langTag;

    final docDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docDir.path}/models/$fullLang');

    if (!await modelDir.exists()) return false;

    final modelFileNamed = File('${modelDir.path}/${fullLang}_model.int8.onnx');
    final modelFileStd = File('${modelDir.path}/model.int8.onnx');
    final tokensFile = File('${modelDir.path}/tokens.txt');

    final hasModel = (await modelFileNamed.exists() && (await modelFileNamed.length()) > 10000000) ||
        (await modelFileStd.exists() && (await modelFileStd.length()) > 10000000);

    final hasTokens = await tokensFile.exists() && (await tokensFile.length()) > 100;

    return hasModel && hasTokens;
  }

  /// Downloads the required model.int8.onnx and tokens.txt from GitHub Releases.
  Future<bool> downloadLanguageModel(
    String languageCode, {
    required DownloadProgressCallback onProgress,
  }) async {
    final langTag = languageCode.toLowerCase().trim();
    if (langTag == 'en') return true;

    final modelFileName = _languageModelFileName[langTag];
    if (modelFileName == null) {
      debugPrint('ModelDownloaderService: Unsupported language code $langTag');
      return false;
    }

    final langNameMap = {'te': 'telugu', 'hi': 'hindi', 'ta': 'tamil'};
    final fullLang = langNameMap[langTag] ?? langTag;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${docDir.path}/models/$fullLang');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final modelFile = File('${modelDir.path}/model.int8.onnx');
      final tokensFile = File('${modelDir.path}/tokens.txt');

      // 1. Download tokens.txt if missing
      if (!await tokensFile.exists() || (await tokensFile.length()) < 100) {
        final tokensUrl = '${githubReleaseBaseUrl}tokens.txt';
        debugPrint('Downloading tokens from $tokensUrl...');
        await _downloadFileWithRetry(tokensUrl, tokensFile);
      }

      // 2. Download model.int8.onnx with live progress callback
      final modelUrl = '$githubReleaseBaseUrl$modelFileName';
      debugPrint('Downloading ONNX model from $modelUrl...');
      
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(modelUrl));
      final response = await request.close();

      HttpClientResponse actualResponse = response;
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers.value(HttpHeaders.locationHeader);
        if (redirectUrl != null) {
          final req2 = await client.getUrl(Uri.parse(redirectUrl));
          actualResponse = await req2.close();
        }
      }

      final totalBytes = actualResponse.contentLength;
      int receivedBytes = 0;

      final sink = modelFile.openWrite();
      await for (var chunk in actualResponse) {
        receivedBytes += chunk.length;
        sink.add(chunk);

        final percent = (totalBytes > 0) ? (receivedBytes / totalBytes) : 0.0;
        onProgress(receivedBytes, totalBytes, percent);
      }
      await sink.close();

      debugPrint('ModelDownload Completed for [$langTag]! Total size: $receivedBytes bytes');
      return true;
    } catch (e) {
      debugPrint('ModelDownloaderService Exception: $e');
      return false;
    }
  }

  Future<void> _downloadFileWithRetry(String url, File targetFile) async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    
    HttpClientResponse actualRes = res;
    if (res.statusCode == 302 || res.statusCode == 301) {
      final loc = res.headers.value(HttpHeaders.locationHeader);
      if (loc != null) {
        final req2 = await client.getUrl(Uri.parse(loc));
        actualRes = await req2.close();
      }
    }

    final sink = targetFile.openWrite();
    await actualRes.pipe(sink);
    await sink.close();
  }
}
