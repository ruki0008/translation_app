import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/api_azure_service.dart';
import '../services/ticket_service.dart';
import '../screens/custom_words_edit_screen.dart';
import '../screens/appearance_settings_page.dart';
import '../screens/login_page.dart';

class WhisperAzureTranslatePage extends StatefulWidget {
  const WhisperAzureTranslatePage({super.key});

  @override
  State<WhisperAzureTranslatePage> createState() =>
      _WhisperAzureTranslatePageState();
}

class _WhisperAzureTranslatePageState extends State<WhisperAzureTranslatePage>
    with WidgetsBindingObserver {
  final TicketService _ticketService = TicketService();
  final _recorder = AudioRecorder();
  final AzureApiService _azureApiService = AzureApiService();

  bool _isRecording = false;
  bool _isProcessing = false;
  int _remainingSeconds = 0;

  Timer? _usageTimer;
  Timer? _silenceTimer;
  Timer? _amplitudeTimer;
  Timer? _countdownTimer;

  String? _audioPath;
  final StringBuffer _resultBuffer = StringBuffer();

  double _lastDb = 0;
  static const double silenceThreshold = -30.0;
  static const Duration silenceDuration = Duration(seconds: 2);

  Color _backgroundColor = Colors.white;
  double _fontSize = 18;
  String _fontFamily = "System";

  int _fileIndex = 0; // 🔹 分割番号を維持

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLoginAndLoadRemaining();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllTimers();
    _recorder.dispose();
    super.dispose();
  }

  // -------- 共通強制停止（遷移前・戻る・BG・終了）--------
  Future<void> _handleForceStop() async {
    if (!_isRecording) return;

    _cancelAllTimers();

    try {
      final remaining = await _ticketService.stopTimer(context);
      if (!mounted) return;
      setState(() => _remainingSeconds = remaining);
    } catch (_) {}

    await _stopRecordingInternal();
  }

  void _cancelAllTimers() {
    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();
    _countdownTimer?.cancel();
    _usageTimer?.cancel();
  }

  // -------- ライフサイクル --------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      await _handleForceStop();
    }
  }

  // -------- ログイン & 残高 --------
  Future<void> _checkLoginAndLoadRemaining() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    try {
      final remaining = await _ticketService.getRemainingTime(context);
      if (!mounted) return;
      setState(() => _remainingSeconds = remaining);
    } catch (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds = 0);
    }
  }

  // -------- カウントダウン --------
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
        await _handleForceStop();
      }
    });
  }

  // -------- カスタム単語 --------
  Future<String> _loadPromptWords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    final doc = await FirebaseFirestore.instance
        .collection("custom_words")
        .doc(user.uid)
        .get();

    final words =
        (doc.data()?["words"] as List<dynamic>? ?? []).cast<String>();

    return words.join(", ");
  }

  // -------- 録音開始 --------
  Future<void> _startRecording() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_remainingSeconds <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("チケット残高がありません")),
      );
      return;
    }

    // 🔹 再開時は必ず状態リセット
    _audioPath = null;
    _lastDb = 0;
    _fileIndex = 0;
    _silenceTimer?.cancel();
    _amplitudeTimer?.cancel();

    // ❗ ここを追加（重要）

    try {
      await _ticketService.startTimer(context);

      // 🔹 強制的にカウントダウン再起動
      _startCountdown();

    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("タイマー開始に失敗しました")),
      );
      return;
    }

    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    _audioPath = "${dir.path}/record_0.m4a";

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _audioPath!,
    );

    _startAmplitudeMonitoring();

    if (!mounted) return;
    setState(() => _isRecording = true);
  }

  // -------- 録音停止（手動）--------
  Future<void> _stopRecording() async {
    _cancelAllTimers();

    final remaining = await _ticketService.stopTimer(context);
    if (!mounted) return;
    setState(() => _remainingSeconds = remaining);

    await _stopRecordingInternal();
  }

  Future<void> _stopRecordingInternal() async {
    if (!_isRecording) return;

    await _recorder.stop();

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    if (_audioPath != null) {
      final file = File(_audioPath!);
      if (file.existsSync() && file.lengthSync() > 1000) {
        print("send(final): ${file.path}");
        await _sendFileForTranscription(file);
      }
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  // -------- 無音分割 --------
  void _startAmplitudeMonitoring() {
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 200), (t) async {
      if (!mounted || !_isRecording) {
        t.cancel();
        return;
      }

      final amp = await _recorder.getAmplitude();
      final db = amp.current;

      if (db < -55) return;

      final diff = (db - _lastDb).abs();
      _lastDb = db;
      if (diff < 2.0) return;

      if (db < silenceThreshold) {
        _silenceTimer ??= Timer(silenceDuration, () async {
          if (!_isRecording) return;

          final dir = await getTemporaryDirectory();
          final newPath = "${dir.path}/record_${++_fileIndex}.m4a";
          final oldPath = _audioPath;

          await _recorder.stop();
          await _recorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: newPath,
          );

          _audioPath = newPath;

          if (oldPath != null) {
            final oldFile = File(oldPath);
            if (oldFile.existsSync() && oldFile.lengthSync() > 1000) {
              print("send(split): ${oldFile.path}");
              await _sendFileForTranscription(oldFile);
            }
          }
        });
      } else {
        _silenceTimer?.cancel();
        _silenceTimer = null;
      }
    });
  }

  // -------- 文字起こし＋翻訳 --------
  Future<void> _sendFileForTranscription(File file) async {
    final promptWords = await _loadPromptWords();

    final result = await _azureApiService.transcribeAndTranslate(
      file.path,
      prompt: promptWords,
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

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleForceStop();
        return true;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(title: const Text("音声文字起こし翻訳（有料）")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_remainingSeconds > 0)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "チケット残り時間: ${_formatDuration(_remainingSeconds)}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),

              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _resultBuffer.toString(),
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontFamily:
                          _fontFamily == "System" ? null : _fontFamily,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () async {
                  await _handleForceStop();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomWordsEditPage(),
                    ),
                  );
                },
                child: const Text("固有名詞を登録・編集"),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () async {
                  await _handleForceStop();

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppearanceSettingsPage(
                        backgroundColor: _backgroundColor,
                        fontSize: _fontSize,
                        fontFamily: _fontFamily,
                      ),
                    ),
                  );

                  if (result != null && mounted) {
                    setState(() {
                      _backgroundColor = result["color"];
                      _fontSize = result["size"];
                      _fontFamily = result["font"];
                    });
                  }
                },
                child: const Text("背景・文字サイズ"),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(
                  _isRecording
                      ? "停止"
                      : _isProcessing
                          ? "処理中..."
                          : "話す",
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
      ),
    );
  }
}