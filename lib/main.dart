import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '音声認識＋翻訳デモ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SpeechTranslatePage(),
    );
  }
}

class SpeechTranslatePage extends StatefulWidget {
  const SpeechTranslatePage({super.key});

  @override
  State<SpeechTranslatePage> createState() => _SpeechTranslatePageState();
}

class _SpeechTranslatePageState extends State<SpeechTranslatePage> {
  final SpeechToText _speechToText = SpeechToText();

  bool _speechEnabled = false;
  String _recognizedText = '';
  String _translatedText = '';

  String _currentLocaleId = '';
  List<LocaleName> _locales = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  /// 音声認識の初期化
  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) => print("Speech status: $status"),
      onError: (error) => print("Speech error: $error"),
    );

    if (_speechEnabled) {
      _locales = await _speechToText.locales();
      final ja = _locales.firstWhere(
        (l) => l.localeId.startsWith("ja"),
        orElse: () => _locales.first,
      );

      setState(() {
        _currentLocaleId = ja.localeId;
      });
    }

    setState(() {});
  }

  /// 音声認識開始
  Future<void> _startListening() async {
    setState(() {
      _recognizedText = '';
      _translatedText = '';
    });

    await _speechToText.listen(
      localeId: _currentLocaleId,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenMode: ListenMode.dictation,
      onResult: (result) async {
        final text = result.recognizedWords;

        setState(() {
          _recognizedText = text;
        });

        // 翻訳
        final translated = await translateText(text);
        setState(() {
          _translatedText = translated;
        });
      },
    );
  }

  /// 音声認識停止
  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// 翻訳（FastAPI サーバー連携版）
  Future<String> translateText(String text) async {
    if (text.isEmpty) return "";

    try {
      // FastAPI サーバーのURLに合わせる
      final uri = Uri.parse('http://192.168.11.9:8000/translate');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translation'] ?? '';
      } else {
        return '翻訳失敗: ${response.statusCode}';
      }
    } catch (e) {
      return '翻訳エラー: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("音声認識＋翻訳"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "🎤 話すと自動で文字起こし → 翻訳します",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),

            /// 認識テキスト
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      "📝 文字起こし（日本語）",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _recognizedText.isEmpty
                          ? "ここに文字起こしが表示されます"
                          : _recognizedText,
                      style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    /// 翻訳テキスト
                    const Text(
                      "🌐 翻訳結果",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _translatedText.isEmpty
                          ? "ここに翻訳結果が表示されます"
                          : _translatedText,
                      style: const TextStyle(fontSize: 22, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// ボタン
            ElevatedButton.icon(
              onPressed: _speechToText.isListening
                  ? _stopListening
                  : _startListening,
              icon: Icon(
                _speechToText.isListening ? Icons.stop : Icons.mic,
                size: 30,
              ),
              label: Text(
                _speechToText.isListening ? "停止" : "話す",
                style: const TextStyle(fontSize: 22),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60),
                backgroundColor: _speechToText.isListening
                    ? Colors.redAccent
                    : Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}