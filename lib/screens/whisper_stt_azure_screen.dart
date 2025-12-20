import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'api_azure_service.dart';

class WhisperAzureTranslatePage extends StatefulWidget {
  const WhisperAzureTranslatePage({super.key});

  @override
  State<WhisperAzureTranslatePage> createState() => _WhisperAzureTranslatePage();
}

class _WhisperAzureTranslatePage extends State<WhisperAzureTranslatePage> {
  final AudioRecorder _recorder = AudioRecorder();
  final AzureApiService _azureApiService = AzureApiService();

  bool _isRecording = false;
  String? _audioPath;
  String _resultText = "ここに文字起こし結果が表示されます";

  /// 録音開始
  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      _audioPath = "${dir.path}/record.m4a";

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
        ),
        path: _audioPath!,
      );

      setState(() {
        _isRecording = true;
      });
    }
  }

  /// 録音停止 → 文字起こし
  Future<void> _stopRecording() async {
    await _recorder.stop();

    setState(() {
      _isRecording = false;
      _resultText = "文字起こし中...";
    });

    if (_audioPath != null && File(_audioPath!).existsSync()) {
      final result = await _azureApiService.transcribeAndTranslate(
        _audioPath!,
      );

      if (result != null) {
        setState(() {
          _resultText = "文字起こし: ${result['text']}\n翻訳結果: ${result['translation']}";
        });
      } else {
        setState(() {
          _resultText = "文字起こし/翻訳に失敗しました";
        });
      }
    }
  }
  // Future<void> _stopRecording() async {
  //   await _recorder.stop();

  //   setState(() {
  //     _isRecording = false;
  //     _resultText = "文字起こし中...";
  //   });

  //   if (_audioPath != null && File(_audioPath!).existsSync()) {
  //     final text =
  //         await _apiService.uploadAndTranscribe(_audioPath!);

  //     setState(() {
  //       _resultText = text ?? "文字起こしに失敗しました";
  //     });
  //   }
  // }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("音声文字起こし"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 結果表示
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _resultText,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 開始・停止ボタン
            ElevatedButton.icon(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? "停止" : "録音開始"),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isRecording ? Colors.red : Colors.blue,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed:
                  _isRecording ? _stopRecording : _startRecording,
            ),
          ],
        ),
      ),
    );
  }
}