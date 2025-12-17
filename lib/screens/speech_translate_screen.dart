import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;

class SpeechTranslatePage extends StatefulWidget {
  const SpeechTranslatePage({super.key});

  @override
  State<SpeechTranslatePage> createState() => _SpeechTranslatePageState();
}

class _SpeechTranslatePageState extends State<SpeechTranslatePage> {
  final SpeechToText _speechToText = SpeechToText();
  static const int maxHistory = 8;

  bool _speechEnabled = false;
  bool _isContinuous = false;

  String _currentPartial = '';
  String _currentLocaleId = '';

  List<_SpeechPair> _history = [];
  List<LocaleName> _locales = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) => debugPrint("Speech error: $error"),
    );

    if (_speechEnabled) {
      _locales = await _speechToText.locales();
      final ja = _locales.firstWhere(
        (l) => l.localeId.startsWith("ja"),
        orElse: () => _locales.first,
      );
      _currentLocaleId = ja.localeId;
    }
  }

  void _onSpeechStatus(String status) {
    if (status == "done" && _isContinuous) {
      _listenOnce();
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) return;

    if (_speechToText.isListening) {
      await _speechToText.stop();
      await _speechToText.cancel();
    }

    setState(() {
      _isContinuous = true;
      _currentPartial = '';
      _history.clear();
    });

    _listenOnce();
  }

  Future<void> _listenOnce() async {
    if (!_isContinuous) return;

    await _speechToText.listen(
      localeId: _currentLocaleId,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      listenMode: ListenMode.dictation,
      onResult: (result) async {
        setState(() {
          _currentPartial = result.recognizedWords;
        });

        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          final jaText = result.recognizedWords;
          final enText = await translateText(jaText);

          setState(() {
            _history.add(_SpeechPair(jaText, enText));
            if (_history.length > maxHistory) {
              _history.removeAt(0);
            }
            _currentPartial = '';
          });
        }
      },
    );
  }

  Future<void> _stopListening() async {
    setState(() {
      _isContinuous = false;
    });
    await _speechToText.stop();
    await _speechToText.cancel();
  }

  Future<String> translateText(String text) async {
    try {
      final uri = Uri.parse('http://192.168.11.9:8000/translate');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['translation'] ?? '';
      }
      return '翻訳失敗';
    } catch (e) {
      return '翻訳エラー';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("音声認識＋翻訳")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length + (_currentPartial.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _history.length) {
                  return Text(_currentPartial,
                      style: const TextStyle(fontSize: 20));
                }

                final item = _history[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.ja,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(item.en,
                          style: const TextStyle(
                              fontSize: 20, color: Colors.blue)),
                    ],
                  ),
                );
              },
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isContinuous ? _stopListening : _startListening,
            icon: Icon(_isContinuous ? Icons.stop : Icons.mic),
            label: Text(_isContinuous ? "停止" : "話す"),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _SpeechPair {
  final String ja;
  final String en;
  _SpeechPair(this.ja, this.en);
}