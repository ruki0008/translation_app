import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'api_service.dart';
import 'custom_words_edit_screen.dart';

class WhisperTranslatePage extends StatefulWidget {
  const WhisperTranslatePage({super.key});

  @override
  State<WhisperTranslatePage> createState() => _WhisperTranslatePage();
}

class _WhisperTranslatePage extends State<WhisperTranslatePage> {
  final AudioRecorder _recorder = AudioRecorder();
  final ApiService _apiService = ApiService();

  bool _isRecording = false;
  bool _isProcessing = false;

  String? _audioPath;
  final StringBuffer _resultBuffer = StringBuffer();

  Timer? _silenceTimer;
  Timer? _amplitudeTimer;

  static const double silenceThreshold = -40.0;
  static const Duration silenceDuration = Duration(seconds: 2);

  /// 固有名詞入力フォーム
  final TextEditingController _promptController = TextEditingController();

  /// Firestore コレクション
  final promptsRef = FirebaseFirestore.instance.collection("prompts");

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();
    _recorder.dispose();
    _promptController.dispose();
    super.dispose();
  }

  // ======================================================
  // 🔹 固有名詞を Firestore に保存
  // ======================================================
  Future<void> _savePromptWord() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    await promptsRef.add({
      "word": text,
      "createdAt": DateTime.now(),
    });

    _promptController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("固有名詞を保存しました")),
    );
  }

  // ======================================================
  // 🔹 Firestore の単語を Whisper に渡すため取得
  // ======================================================
  Future<String> _loadPromptWords() async {
    final snap = await promptsRef.get();
    final words = snap.docs.map((d) => d["word"]).join(", ");
    return words;
  }

  // ======================================================
  // 🔹 録音開始
  // ======================================================
  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    _audioPath = "${dir.path}/record_0.m4a";

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _audioPath!,
    );

    _startAmplitudeMonitoring();

    setState(() => _isRecording = true);
  }

  // ======================================================
  // 🔹 無音検知でファイル分割
  // ======================================================
  void _startAmplitudeMonitoring() {
    int fileIndex = 1;

    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) async {
        final amp = await _recorder.getAmplitude();
        final db = amp.current;

        if (db < silenceThreshold) {
          _silenceTimer ??= Timer(silenceDuration, () async {
            if (!_isRecording) return;

            final dir = await getTemporaryDirectory();
            final newPath = "${dir.path}/record_$fileIndex.m4a";
            fileIndex++;

            await _recorder.stop();
            await _recorder.start(
              const RecordConfig(encoder: AudioEncoder.aacLc),
              path: newPath,
            );

            final oldFile =
                File("${dir.path}/record_${fileIndex - 2}.m4a");

            _audioPath = newPath;

            if (oldFile.existsSync() && oldFile.lengthSync() > 1000) {
              _sendFileForTranscription(oldFile);
            }
          });
        } else {
          _silenceTimer?.cancel();
          _silenceTimer = null;
        }
      },
    );
  }

  // ======================================================
  // 🔹 録音停止
  // ======================================================
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();

    await _recorder.stop();

    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    if (_audioPath != null &&
        File(_audioPath!).existsSync() &&
        File(_audioPath!).lengthSync() > 1000) {
      await _sendFileForTranscription(File(_audioPath!));
    }

    setState(() => _isProcessing = false);
  }

  // ======================================================
  // 🔹 Whisper へ送信
  //    Firestoreの固有名詞を一緒に渡す
  // ======================================================
  Future<void> _sendFileForTranscription(File file) async {
    final promptWords = await _loadPromptWords();

    final result = await _apiService.transcribeAndTranslate(
      file.path,
      prompt: promptWords, // ← ★ 追加
    );

    if (!mounted) return;

    if (result != null) {
      _resultBuffer.writeln("文字起こし: ${result['text']}");
      _resultBuffer.writeln("翻訳結果: ${result['translation']}\n");
    } else {
      _resultBuffer.writeln("文字起こし/翻訳に失敗しました\n");
    }

    setState(() {});
  }

  // ======================================================
  // 🔹 UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("音声文字起こし")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _resultBuffer.toString(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomWordsEditPage()),
                );
              },
              child: const Text("固有名詞を登録・編集（最大20件）"),
            ),

            const SizedBox(height: 16),

            // 録音ボタン
            ElevatedButton.icon(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(
                _isRecording
                    ? "停止"
                    : _isProcessing
                        ? "処理中..."
                        : "録音開始",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isRecording ? Colors.red : Colors.blue,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _isProcessing
                  ? null
                  : _isRecording
                      ? _stopRecording
                      : _startRecording,
            ),
          ],
        ),
      ),
    );
  }
}