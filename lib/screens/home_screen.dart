import 'package:flutter/material.dart';
import 'speech_translate_screen.dart';
import 'whisper_stt_screen.dart';
import 'whisper_stt_azure_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('SpeechToText 翻訳'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SpeechTranslatePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud),
              label: const Text('Whisper 翻訳'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WhisperTranslatePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud),
              label: const Text('Whisper Azure 翻訳'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WhisperAzureTranslatePage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}