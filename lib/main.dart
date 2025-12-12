import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Speech Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SpeechToTextPage(),
    );
  }
}

class SpeechToTextPage extends StatefulWidget {
  const SpeechToTextPage({super.key});

  @override
  State<SpeechToTextPage> createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  String _currentLocaleId = '';
  List<LocaleName> _localeNames = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  /// 初期化
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        print('Speech status: $status');
      },
      onError: (error) {
        print('Speech error: $error');
      },
    );

    if (_speechEnabled) {
      _localeNames = await _speechToText.locales();

      // 日本語を優先
      final jaLocale = _localeNames.firstWhere(
        (locale) => locale.localeId.startsWith('ja'),
        orElse: () => _localeNames.first,
      );

      setState(() {
        _currentLocaleId = jaLocale.localeId;
      });
    }

    setState(() {});
  }

  /// 認識開始
  void _startListening() async {
    _lastWords = '';
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords; // ← 正しい取り方
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: _currentLocaleId,
      partialResults: true,
      cancelOnError: true,

      /// ★ iOS で安定するモード
      listenMode: ListenMode.dictation,
    );
  }

  /// 認識停止
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音声認識アプリ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'マイクを有効にして話し始めてください...',
                style: TextStyle(fontSize: 20),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _speechToText.isListening
                      ? _lastWords
                      : _speechEnabled
                          ? (_lastWords.isEmpty ? 'タップして話し始める' : _lastWords)
                          : '音声認識が利用できません',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed:
                    _speechToText.isListening ? _stopListening : _startListening,
                icon:
                    Icon(_speechToText.isListening ? Icons.stop : Icons.mic),
                label: Text(
                    _speechToText.isListening ? '認識停止' : '認識開始'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 70),
                  textStyle: const TextStyle(fontSize: 22),
                  backgroundColor: _speechToText.isListening
                      ? Colors.redAccent
                      : Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}