import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

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

  static const double silenceThreshold = -40.0; // dB
  static const Duration silenceDuration = Duration(seconds: 1);

  /// 録音開始
  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    _audioPath = "${dir.path}/record.m4a";

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _audioPath!,
    );

    _startAmplitudeMonitoring();

    setState(() {
      _isRecording = true;
    });
  }

  /// 振幅監視（無音検知）
  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();

    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) async {
        final amp = await _recorder.getAmplitude();
        final db = amp.current;

        if (db < silenceThreshold) {
          _silenceTimer ??= Timer(silenceDuration, _autoStop);
        } else {
          _silenceTimer?.cancel();
          _silenceTimer = null;
        }
      },
    );
  }

  /// 無音による自動停止
  Future<void> _autoStop() async {
    if (!_isRecording) return;
    await _stopRecording(auto: true);
  }

  /// 録音停止
  Future<void> _stopRecording({bool auto = false}) async {
    if (!_isRecording) return;

    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();

    await _recorder.stop();

    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    if (!auto) return; // 手動停止時は処理中断

    if (_audioPath != null && File(_audioPath!).existsSync()) {
      final result =
          await _apiService.transcribeAndTranslate(_audioPath!);

      if (!mounted) return;

      if (result != null) {
        _resultBuffer.writeln("文字起こし: ${result['text']}");
        _resultBuffer.writeln("翻訳結果: ${result['translation']}\n");
      } else {
        _resultBuffer.writeln("文字起こし/翻訳に失敗しました\n");
      }

      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("音声文字起こし")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 結果表示
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _resultBuffer.toString(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// ボタン
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
                      ? () => _stopRecording(auto: false)
                      : _startRecording,
            ),
          ],
        ),
      ),
    );
  }
}